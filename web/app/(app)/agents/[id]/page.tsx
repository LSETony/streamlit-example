import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getT } from "@/lib/i18n/server";
import { appOrigin } from "@/lib/origin";
import { agentsConfigured } from "@/lib/ai/runner";
import type { AgentRow } from "@/lib/ai/execute";
import { AgentEditor } from "./agent-editor";
import { RunPanel, type RunRow } from "./run-panel";
import { KeysPanel, type KeyRow } from "./keys-panel";

// запуск агента идёт внутри серверного действия этой страницы и может занять несколько минут
export const maxDuration = 300;

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("ИИ-агенты") };
}

export default async function AgentPage({ params }: PageProps<"/agents/[id]">) {
  const ctx = await requireStaff(["owner", "admin"]);
  const { id } = await params;
  const supabase = await createClient();
  if (id === "new") {
    return (
      <>
        <PageHeader title="Новый агент" back={{ href: "/agents", label: "ИИ-агенты" }} />
        <AgentEditor agent={null} readOnly={ctx.readOnly} />
      </>
    );
  }
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const { data: agent } = await supabase.from("ai_agents").select("*").eq("id", id).eq("gym_id", ctx.gym.id).maybeSingle();
  if (!agent) notFound();
  const a = agent as AgentRow;
  const [{ data: runs }, { data: keys }] = await Promise.all([
    a.kind === "builtin"
      ? supabase.from("ai_agent_runs").select("id, source, prompt, output, steps, status, error, created_at").eq("agent_id", a.id).order("created_at", { ascending: false }).limit(10)
      : Promise.resolve({ data: [] }),
    a.kind === "external"
      ? supabase.from("ai_agent_keys").select("id, prefix, created_at, last_used_at, revoked_at").eq("agent_id", a.id).order("created_at", { ascending: false })
      : Promise.resolve({ data: [] }),
  ]);
  return (
    <>
      <PageHeader title={a.name} back={{ href: "/agents", label: "ИИ-агенты" }} />
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
        <AgentEditor agent={a} readOnly={ctx.readOnly} />
        {a.kind === "builtin" ? (
          <RunPanel agentId={a.id} defaultTask={a.task} runs={(runs ?? []) as RunRow[]} timezone={ctx.gym.timezone}
            disabled={ctx.readOnly || !a.enabled} configured={agentsConfigured()} />
        ) : (
          <KeysPanel agentId={a.id} keys={(keys ?? []) as KeyRow[]} origin={await appOrigin()} timezone={ctx.gym.timezone} readOnly={ctx.readOnly} />
        )}
      </div>
    </>
  );
}
