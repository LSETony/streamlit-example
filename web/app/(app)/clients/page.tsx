import type { Metadata } from "next";
import Link from "next/link";
import { Smartphone, Upload, Users } from "lucide-react";
import { PageHeader } from "@/components/app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState, Avatar } from "@/components/ui/misc";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { MembershipStateBadge } from "@/components/status";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { dateTime, phone } from "@/lib/format";
import type { ClientRow } from "@/lib/types";
import { ClientFilters } from "./client-filters";
import { NewClientButton } from "./new-client";
import { ExportClientsButton } from "./export-button";

export const metadata: Metadata = { title: "Клиенты" };
const PAGE = 50;

export default async function ClientsPage({ searchParams }: PageProps<"/clients">) {
  const ctx = await requireStaff();
  const sp = await searchParams;
  const q = typeof sp.q === "string" ? sp.q.trim() : "";
  const state = typeof sp.state === "string" ? sp.state : "";
  const tag = typeof sp.tag === "string" ? sp.tag : "";
  const risk = sp.risk === "1";
  const page = Math.max(1, Number(sp.page) || 1);

  const supabase = await createClient();
  let query = supabase.from("v_clients").select("*", { count: "exact" }).eq("gym_id", ctx.gym.id);
  if (q) {
    const digits = q.replace(/\D/g, "");
    if (digits.length >= 3 && !/[a-zа-яё]/i.test(q)) query = query.like("phone", `%${digits.length >= 10 ? digits.slice(-10) : digits.replace(/^[78]/, "")}%`);
    else query = query.ilike("full_name", `%${q.replace(/[%_]/g, "")}%`);
  }
  if (state) query = query.eq("membership_state", state);
  if (tag) query = query.contains("tags", [tag]);
  if (risk) {
    const { data: riskIds } = await supabase.from("v_client_risk").select("client_id").eq("gym_id", ctx.gym.id);
    query = query.in("id", (riskIds ?? []).map((r) => r.client_id).concat(["00000000-0000-0000-0000-000000000000"]));
  }
  const { data, count } = await query.order("full_name").range((page - 1) * PAGE, page * PAGE - 1);
  const rows = (data ?? []) as ClientRow[];
  const { data: tagRows } = await supabase.from("clients").select("tags").eq("gym_id", ctx.gym.id).is("deleted_at", null).neq("tags", "{}").limit(1000);
  const tags = Array.from(new Set((tagRows ?? []).flatMap((r) => r.tags as string[]))).sort();
  const total = count ?? 0;
  const canImport = ctx.staff.role !== "reception";

  const pageHref = (p: number) => {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (state) params.set("state", state);
    if (tag) params.set("tag", tag);
    if (risk) params.set("risk", "1");
    params.set("page", String(p));
    return `/clients?${params}`;
  };

  return (
    <>
      <PageHeader
        title="Клиенты"
        description={`${total} ${total === 1 ? "клиент" : "клиентов"}${q || state || tag || risk ? " по фильтру" : ""}`}
        actions={
          <>
            {canImport ? (
              <Button variant="outline" asChild><Link href="/clients/import"><Upload /> Импорт</Link></Button>
            ) : null}
            {ctx.features.export !== false ? <ExportClientsButton gymId={ctx.gym.id} filters={{ q, state, tag, risk }} /> : null}
            <NewClientButton disabled={ctx.readOnly} autoOpen={sp.new === "1"} />
          </>
        }
      />
      <ClientFilters q={q} state={state} tag={tag} risk={risk} tags={tags} showRisk={ctx.features.risk !== false} />
      {rows.length === 0 ? (
        <EmptyState
          icon={<Users />}
          title={q || state || tag || risk ? "Никого не нашли" : "Клиентов пока нет"}
          action={!q && !state && !tag && !risk && canImport ? <Button asChild><Link href="/clients/import"><Upload /> Импортировать из Excel</Link></Button> : undefined}
        >
          {q || state || tag || risk ? "Попробуйте изменить поиск или фильтры." : "Перенесите базу из Excel за пару минут или добавьте первого клиента."}
        </EmptyState>
      ) : (
        <Card>
          <Table>
            <THead>
              <TR>
                <TH>Клиент</TH>
                <TH>Телефон</TH>
                <TH>Абонемент</TH>
                <TH className="hidden md:table-cell">Последний визит</TH>
                <TH className="hidden lg:table-cell">Источник</TH>
              </TR>
            </THead>
            <TBody>
              {rows.map((c) => (
                <TR key={c.id} className="relative transition-colors hover:bg-field">
                  <TD>
                    <Link href={`/clients/${c.id}`} className="flex items-center gap-3 after:absolute after:inset-0">
                      <Avatar name={c.full_name} className="size-8 text-xs" />
                      <span className="font-medium">{c.full_name}</span>
                      {c.in_app ? <Smartphone className="size-3.5 text-muted-foreground" aria-label="Подключён к приложению" /> : null}
                    </Link>
                  </TD>
                  <TD className="tabular whitespace-nowrap text-muted-foreground">{phone(c.phone)}</TD>
                  <TD>
                    <div className="flex flex-wrap items-center gap-2">
                      <MembershipStateBadge state={c.membership_state} endsOn={c.membership_ends_on} />
                      {c.plan_name ? <span className="hidden text-xs text-muted-foreground sm:inline">{c.plan_name}{c.visits_left !== null ? ` · ${c.visits_left} виз.` : ""}</span> : null}
                    </div>
                  </TD>
                  <TD className="hidden whitespace-nowrap text-muted-foreground md:table-cell">{c.last_visit_at ? dateTime(c.last_visit_at, ctx.gym.timezone) : "—"}</TD>
                  <TD className="hidden text-muted-foreground lg:table-cell">{c.source ?? "—"}</TD>
                </TR>
              ))}
            </TBody>
          </Table>
          {total > PAGE ? (
            <div className="flex items-center justify-between border-t border-border px-4 py-3 text-sm">
              <span className="text-muted-foreground">{(page - 1) * PAGE + 1}–{Math.min(page * PAGE, total)} из {total}</span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" asChild disabled={page <= 1}>
                  {page > 1 ? <Link href={pageHref(page - 1)}>Назад</Link> : <span>Назад</span>}
                </Button>
                <Button variant="outline" size="sm" asChild>
                  {page * PAGE < total ? <Link href={pageHref(page + 1)}>Дальше</Link> : <span>Дальше</span>}
                </Button>
              </div>
            </div>
          ) : null}
        </Card>
      )}
    </>
  );
}
