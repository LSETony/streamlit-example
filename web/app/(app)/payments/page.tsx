import type { Metadata } from "next";
import Link from "next/link";
import { PageHeader } from "@/components/app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { PaymentStatusBadge } from "@/components/status";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { addDays, date, dateTime, money, zonedToUtc } from "@/lib/format";
import { METHOD_LABEL, type PaymentMethod, type PaymentStatus } from "@/lib/types";
import { PaymentFilters } from "./filters";
import { ExportPayments } from "./export";
import { RefundButton } from "./refund-button";
import { getT } from "@/lib/i18n/server";
import { paymentDescription } from "@/lib/i18n/core";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Оплаты") };
}
const PAGE = 50;

export interface PaymentListRow {
  id: string; amount: number; method: PaymentMethod; status: PaymentStatus; refund_of_id: string | null; membership_id: string | null;
  paid_at: string | null; created_at: string; description: string | null; client_id: string | null;
  clients: { full_name: string } | null; staff: { full_name: string } | null;
}

export default async function PaymentsPage({ searchParams }: PageProps<"/payments">) {
  const ctx = await requireStaff(["owner", "admin"]);
  const t = await getT();
  const sp = await searchParams;
  const from = typeof sp.from === "string" ? sp.from : ctx.today;
  const to = typeof sp.to === "string" ? sp.to : ctx.today;
  const method = typeof sp.method === "string" ? sp.method : "";
  const status = typeof sp.status === "string" ? sp.status : "";
  const page = Math.max(1, Number(sp.page) || 1);
  const tz = ctx.gym.timezone;
  const supabase = await createClient();

  let q = supabase.from("payments").select("*, clients(full_name), staff(full_name)").eq("gym_id", ctx.gym.id)
    .gte("created_at", zonedToUtc(from, "00:00", tz).toISOString())
    .lt("created_at", zonedToUtc(addDays(to, 1), "00:00", tz).toISOString());
  if (method) q = q.eq("method", method);
  if (status === "refunds") q = q.not("refund_of_id", "is", null);
  else if (status) q = q.eq("status", status).is("refund_of_id", null);
  const [{ data }, { data: summary }] = await Promise.all([
    q.order("created_at", { ascending: false }).limit(1000),
    supabase.rpc("payments_summary", { p_gym: ctx.gym.id, p_from: from, p_to: to }),
  ]);
  const rows = (data ?? []) as unknown as PaymentListRow[];
  const shown = rows.slice((page - 1) * PAGE, page * PAGE);
  const pageHref = (p: number) => {
    const params = new URLSearchParams({ from, to });
    if (method) params.set("method", method);
    if (status) params.set("status", status);
    params.set("page", String(p));
    return `/payments?${params}`;
  };
  const s = (summary ?? {}) as { income: number; refunds: number; net: number; cash: number; card: number; online: number; count: number };

  return (
    <>
      <PageHeader title="Оплаты" description={from === to ? date(from) : `${date(from)} – ${date(to)}`}
        actions={<ExportPayments rows={rows} timezone={tz} from={from} to={to} />} />
      <PaymentFilters from={from} to={to} method={method} status={status} today={ctx.today} />

      <div className="mb-4 grid grid-cols-2 gap-3 md:grid-cols-5 [&>*:first-child]:col-span-2 md:[&>*:first-child]:col-span-1">
        <Sum label={t("Итого")} value={money(s.net)} strong />
        <Sum label={t("Наличные")} value={money(s.cash)} />
        <Sum label={t("Карта")} value={money(s.card)} />
        <Sum label={t("Онлайн")} value={money(s.online)} />
        <Sum label={t("Возвраты")} value={s.refunds ? `−${money(s.refunds)}` : money(0)} />
      </div>

      {rows.length === 0 ? <EmptyState title="Оплат за период нет" /> : (
        <Card className="overflow-hidden">
          {/* телефон: список iOS — клиент и время слева, сумма и статус справа */}
          <ul className="md:hidden">
            {shown.map((p) => (
              <li key={p.id} className="ios-sep">
                <div className="flex min-h-[60px] items-center gap-3 px-4 py-2.5">
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[17px] leading-[22px]">
                      {p.client_id ? <Link className="font-medium active:opacity-60" href={`/clients/${p.client_id}`}>{p.clients?.full_name}</Link> : "—"}
                    </span>
                    <span className="block truncate text-[13px] leading-[18px] text-muted-foreground tabular">
                      {dateTime(p.paid_at ?? p.created_at, tz)} · {t(METHOD_LABEL[p.method])}
                    </span>
                  </span>
                  <span className="grid justify-items-end gap-1">
                    <span className={p.refund_of_id ? "text-[17px] font-semibold tabular text-destructive" : "text-[17px] font-semibold tabular"}>{p.refund_of_id ? "−" : ""}{money(p.amount)}</span>
                    <PaymentStatusBadge status={p.status} isRefund={!!p.refund_of_id} />
                  </span>
                </div>
              </li>
            ))}
          </ul>
          <Table className="hidden md:table">
            <THead><TR><TH>Время</TH><TH>Клиент</TH><TH>Сумма</TH><TH>Способ</TH><TH>Статус</TH><TH className="hidden lg:table-cell">Назначение</TH><TH className="hidden xl:table-cell">Принял</TH><TH /></TR></THead>
            <TBody>
              {shown.map((p) => (
                <TR key={p.id} className="transition-colors hover:bg-field">
                  <TD className="whitespace-nowrap tabular">{dateTime(p.paid_at ?? p.created_at, tz)}</TD>
                  <TD>{p.client_id ? <Link className="font-medium hover:underline" href={`/clients/${p.client_id}`}>{p.clients?.full_name}</Link> : "—"}</TD>
                  <TD className={p.refund_of_id ? "whitespace-nowrap tabular text-destructive" : "whitespace-nowrap font-medium tabular"}>{p.refund_of_id ? "−" : ""}{money(p.amount)}</TD>
                  <TD>{t(METHOD_LABEL[p.method])}</TD>
                  <TD><PaymentStatusBadge status={p.status} isRefund={!!p.refund_of_id} /></TD>
                  <TD className="hidden text-muted-foreground lg:table-cell">{paymentDescription(t, p.description)}</TD>
                  <TD className="hidden text-muted-foreground xl:table-cell">{p.staff?.full_name ?? (p.method === "online" ? t("приложение") : "—")}</TD>
                  <TD className="text-right">
                    {!p.refund_of_id && p.status === "succeeded" && !ctx.readOnly ? <RefundButton payment={p} /> : null}
                  </TD>
                </TR>
              ))}
            </TBody>
          </Table>
          {rows.length > PAGE ? (
            <div className="flex items-center justify-between border-t border-border px-4 py-3 text-sm">
              <span className="text-muted-foreground">{(page - 1) * PAGE + 1}–{Math.min(page * PAGE, rows.length)} {t("из")} {rows.length}</span>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" asChild disabled={page <= 1}>
                  {page > 1 ? <Link href={pageHref(page - 1)}>Назад</Link> : <span>Назад</span>}
                </Button>
                <Button variant="outline" size="sm" asChild>
                  {page * PAGE < rows.length ? <Link href={pageHref(page + 1)}>Дальше</Link> : <span>Дальше</span>}
                </Button>
              </div>
            </div>
          ) : null}
        </Card>
      )}
    </>
  );
}

function Sum({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <Card variant={strong ? "hero" : "glass"} className="grid gap-1 p-4">
      <span className="text-xs text-muted-foreground">{label}</span>
      <span className={strong ? "text-2xl font-semibold tabular" : "text-lg font-medium tabular"}>{value}</span>
    </Card>
  );
}
