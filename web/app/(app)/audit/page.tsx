import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/app-shell";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { dateTime, money } from "@/lib/format";
import { getT } from "@/lib/i18n/server";
import type { T } from "@/lib/i18n/core";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Журнал действий") };
}

const ENTITY: Record<string, string> = { memberships: "Абонемент", payments: "Оплата", freezes: "Заморозка", membership_plans: "Тариф", staff: "Сотрудник", gyms: "Настройки зала" };
const ACTION: Record<string, string> = { insert: "создал(а)", update: "изменил(а)", delete: "удалил(а)" };
const FIELD: Record<string, string> = {
  status: "статус", ends_on: "окончание", starts_on: "начало", price: "цена", price_paid: "цена", amount: "сумма", visits_left: "визиты",
  freeze_days_used: "дни заморозки", active: "активен", role: "роль", name: "название", settings: "настройки", method: "способ",
};

function describe(t: T, cur: string, entity: string, action: string, diff: Record<string, unknown> | null): string {
  if (!diff) return "";
  if (action === "update") {
    return Object.entries(diff).filter(([k]) => FIELD[k]).map(([k, v]) => {
      const [a, b] = v as [unknown, unknown];
      const f = (x: unknown) => (k === "price" || k === "price_paid" || k === "amount") && typeof x === "number" ? money(x, cur) : k === "settings" ? "…" : String(x);
      return `${t(FIELD[k])}: ${f(a)} → ${f(b)}`;
    }).join("; ");
  }
  if (entity === "payments") return `${t(diff.refund_of_id ? "возврат" : "оплата")} ${money(diff.amount as number, cur)} (${diff.method})`;
  if (entity === "memberships") return `«${diff.plan_name}» ${diff.starts_on} – ${diff.ends_on}`;
  if (entity === "freezes") return `${diff.from_date} – ${diff.to_date}`;
  if (entity === "membership_plans") return `«${diff.name}» ${money(diff.price as number, cur)}`;
  if (entity === "staff") return `${diff.full_name} (${diff.role})`;
  return "";
}

/** FR-1.4 Журнал действий: кто, когда и что изменил в абонементах и оплатах */
export default async function AuditPage({ searchParams }: PageProps<"/audit">) {
  const ctx = await requireStaff(["owner"]);
  const t = await getT();
  const sp = await searchParams;
  const page = Math.max(1, Number(sp.page) || 1);
  const entity = typeof sp.entity === "string" ? sp.entity : "";
  const supabase = await createClient();
  let q = supabase.from("audit_log").select("*").eq("gym_id", ctx.gym.id);
  if (entity) q = q.eq("entity", entity);
  const { data } = await q.order("at", { ascending: false }).range((page - 1) * 100, page * 100 - 1);
  const { data: people } = await supabase.from("staff").select("user_id, full_name").eq("gym_id", ctx.gym.id);
  const names = new Map((people ?? []).map((p) => [p.user_id, p.full_name]));
  const rows = data ?? [];
  return (
    <>
      <PageHeader title="Журнал действий" description="Изменения абонементов, оплат, тарифов, сотрудников и настроек" />
      <div className="mb-4 flex flex-wrap gap-2">
        {[["", "Все"], ["memberships", "Абонементы"], ["payments", "Оплаты"], ["freezes", "Заморозки"], ["membership_plans", "Тарифы"], ["staff", "Сотрудники"], ["gyms", "Настройки"]].map(([k, l]) => (
          <Button key={k} size="sm" variant={entity === k ? "default" : "outline"} asChild><Link href={k ? `/audit?entity=${k}` : "/audit"}>{l}</Link></Button>
        ))}
      </div>
      {rows.length === 0 ? <EmptyState title="Записей нет" /> : (
        <Card>
          <Table>
            <THead><TR><TH>Когда</TH><TH>Кто</TH><TH>Что</TH><TH>Подробности</TH></TR></THead>
            <TBody>
              {rows.map((r) => (
                <TR key={r.id}>
                  <TD className="whitespace-nowrap tabular">{dateTime(r.at, ctx.gym.timezone)}</TD>
                  <TD>{r.actor_user_id ? names.get(r.actor_user_id) ?? t("клиент (приложение)") : t("система")}</TD>
                  <TD className="whitespace-nowrap">{ACTION[r.action] ? t(ACTION[r.action]) : r.action} · {ENTITY[r.entity] ? t(ENTITY[r.entity]) : r.entity}</TD>
                  <TD className="text-muted-foreground">{describe(t, ctx.gym.currency ?? "RUB", r.entity, r.action, r.diff)}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
          <div className="flex justify-end gap-2 border-t border-border p-3">
            {page > 1 ? <Button size="sm" variant="outline" asChild><Link href={`/audit?page=${page - 1}${entity ? `&entity=${entity}` : ""}`}>Новее</Link></Button> : null}
            {rows.length === 100 ? <Button size="sm" variant="outline" asChild><Link href={`/audit?page=${page + 1}${entity ? `&entity=${entity}` : ""}`}>Старее</Link></Button> : null}
          </div>
        </Card>
      )}
    </>
  );
}
