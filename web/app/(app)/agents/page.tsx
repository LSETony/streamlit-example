import type { Metadata } from "next";
import Link from "next/link";
import { Bot, Plug, Plus } from "lucide-react";
import { PageHeader } from "@/components/app-shell";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Alert, EmptyState } from "@/components/ui/misc";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getT } from "@/lib/i18n/server";
import { dateTime } from "@/lib/format";
import { AGENT_TEMPLATES } from "@/lib/ai/tools";
import { agentsConfigured } from "@/lib/ai/runner";
import { ActionQueue, type ActionRow } from "./action-queue";

export const maxDuration = 60;

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("ИИ-агенты") };
}

export default async function AgentsPage() {
  const ctx = await requireStaff(["owner", "admin"]);
  const t = await getT();
  const supabase = await createClient();
  const [{ data: agents }, { data: actions }] = await Promise.all([
    supabase.from("ai_agents").select("id, name, kind, template, enabled, schedule, last_run_at, tools").eq("gym_id", ctx.gym.id).order("created_at"),
    supabase.from("ai_agent_actions").select("id, agent_id, tool, args, reason, status, error, created_at, decided_at")
      .eq("gym_id", ctx.gym.id).order("created_at", { ascending: false }).limit(60),
  ]);
  const names = Object.fromEntries((agents ?? []).map((a) => [a.id, a.name]));
  const clientIds = [...new Set((actions ?? []).map((a) => (a.args as { client_id?: string })?.client_id).filter((x): x is string => !!x))];
  const { data: clients } = clientIds.length
    ? await supabase.from("clients").select("id, full_name").eq("gym_id", ctx.gym.id).in("id", clientIds)
    : { data: [] as { id: string; full_name: string }[] };
  const clientNames = Object.fromEntries((clients ?? []).map((c) => [c.id, c.full_name]));
  const rows = (actions ?? []).map((a) => ({
    ...a, agent_name: names[a.agent_id] ?? "", client_name: clientNames[(a.args as { client_id?: string })?.client_id ?? ""] ?? null,
  })) as ActionRow[];
  const pending = rows.filter((a) => a.status === "pending");
  const history = rows.filter((a) => a.status !== "pending").slice(0, 30);

  return (
    <>
      <PageHeader
        title="ИИ-агенты"
        description="Агенты работают с клиентами и расписанием зала в рамках прав, которые вы им дали. Действия, требующие подтверждения, появляются здесь."
        actions={ctx.readOnly ? null : <Button asChild><Link href="/agents/new"><Plus /> Новый агент</Link></Button>}
      />
      {!agentsConfigured() ? (
        <Alert variant="warning" className="mb-4">
          {t("Встроенные агенты не подключены: на сервере не задан ANTHROPIC_API_KEY. Внешние агенты по API-ключу работают и без него.")}
        </Alert>
      ) : null}

      {pending.length ? (
        <section className="mb-6 grid gap-3">
          <h2 className="pl-1 text-lg font-semibold">{t("Ждут подтверждения")} <Badge variant="warning">{pending.length}</Badge></h2>
          <ActionQueue rows={pending} timezone={ctx.gym.timezone} readOnly={ctx.readOnly} />
        </section>
      ) : null}

      {(agents ?? []).length === 0 ? (
        <EmptyState icon={<Bot />} title="Агентов пока нет"
          action={ctx.readOnly ? null : <Button asChild><Link href="/agents/new"><Plus /> Создать агента</Link></Button>}>
          Начните с шаблона: агент удержания сам разбирает «В зоне риска» и пишет клиентам, аналитик готовит сводку по залу. Внешнего агента (ChatGPT, Claude, n8n) можно подключить по API-ключу или через MCP.
        </EmptyState>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {(agents ?? []).map((a) => {
            const tpl = AGENT_TEMPLATES.find((x) => x.id === a.template);
            const toolsOn = Object.keys(a.tools ?? {}).length;
            return (
              <Link key={a.id} href={`/agents/${a.id}`} className="group">
                <Card className={`grid h-full gap-3 p-5 transition group-hover:brightness-[0.98] ${a.enabled ? "" : "opacity-60"}`}>
                  <div className="flex items-start gap-3">
                    <div className="grid size-10 shrink-0 place-items-center rounded-full bg-tint-soft text-tint-text">{a.kind === "builtin" ? <Bot className="size-5" /> : <Plug className="size-5" />}</div>
                    <div className="min-w-0">
                      <p className="truncate font-semibold">{a.name}</p>
                      <p className="text-xs text-muted-foreground">{t(a.kind === "builtin" ? "Встроенный агент" : "Внешний агент")}{tpl && tpl.id !== "custom" ? ` · ${t(tpl.label)}` : ""}</p>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    <Badge variant={a.enabled ? "success" : "outline"}>{a.enabled ? "Включён" : "Выключен"}</Badge>
                    {a.schedule === "daily" ? <Badge variant="info">Каждый день</Badge> : null}
                    <Badge variant="outline">{t("Инструментов: {n}", { n: toolsOn })}</Badge>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {a.last_run_at ? t("Последний запуск: {at}", { at: dateTime(a.last_run_at, ctx.gym.timezone) }) : t("Ещё не запускался")}
                  </p>
                </Card>
              </Link>
            );
          })}
        </div>
      )}

      {history.length ? (
        <section className="mt-8 grid gap-3">
          <h2 className="pl-1 text-lg font-semibold">{t("Журнал действий агентов")}</h2>
          <ActionQueue rows={history} timezone={ctx.gym.timezone} readOnly />
        </section>
      ) : null}
    </>
  );
}
