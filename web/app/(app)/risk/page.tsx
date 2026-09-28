import type { Metadata } from "next";
import { PageHeader } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { RiskReason, RiskRow } from "@/lib/types";
import { RiskList } from "./risk-list";

export const metadata: Metadata = { title: "В зоне риска" };

export default async function RiskPage({ searchParams }: PageProps<"/risk">) {
  const ctx = await requireStaff();
  const sp = await searchParams;
  const reason = (typeof sp.reason === "string" ? sp.reason : "") as RiskReason | "";
  const supabase = await createClient();
  const [{ data }, { data: stats }] = await Promise.all([
    supabase.from("v_client_risk").select("*").eq("gym_id", ctx.gym.id).order("urgency", { ascending: false }).limit(500),
    supabase.rpc("risk_returned_stats", { p_gym: ctx.gym.id }),
  ]);
  const s = (stats ?? { contacted: 0, returned: 0 }) as { contacted: number; returned: number };
  return (
    <>
      <PageHeader
        title="В зоне риска"
        description="Клиенты, которых зал может потерять. Список обновляется сразу после визита или продажи."
      />
      <RiskList
        rows={(data ?? []) as RiskRow[]}
        initialReason={reason}
        gymName={ctx.gym.name}
        templates={ctx.gym.settings?.message_templates}
        timezone={ctx.gym.timezone}
        stats={s}
        readOnly={ctx.readOnly}
      />
    </>
  );
}
