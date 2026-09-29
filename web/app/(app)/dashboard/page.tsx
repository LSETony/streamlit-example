import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { PageHeader } from "@/components/app-shell";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert } from "@/components/ui/misc";
import { RiskBadge } from "@/components/status";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { addDays, date, money, plural } from "@/lib/format";
import type { Dashboard, RiskReason } from "@/lib/types";
import { PeriodPicker } from "./period-picker";
import { Heatmap } from "@/components/charts/heatmap";
import { ColumnChart } from "@/components/charts/column-chart";
import { BarList } from "@/components/charts/bar-list";
import { Delta } from "@/components/charts/delta";

export const metadata: Metadata = { title: "Дашборд" };

function resolvePeriod(p: string | undefined, today: string, from?: string, to?: string): { from: string | null; to: string | null; key: string } {
  const monthStart = today.slice(0, 8) + "01";
  switch (p) {
    case "prev_month": {
      const prevEnd = addDays(monthStart, -1);
      return { from: prevEnd.slice(0, 8) + "01", to: prevEnd, key: p };
    }
    case "7d": return { from: addDays(today, -6), to: today, key: p };
    case "30d": return { from: addDays(today, -29), to: today, key: p };
    case "custom":
      if (from && to && /^\d{4}-\d{2}-\d{2}$/.test(from) && /^\d{4}-\d{2}-\d{2}$/.test(to)) return { from, to, key: p };
      return { from: null, to: null, key: "month" };
    default: return { from: null, to: null, key: "month" };
  }
}

export default async function DashboardPage({ searchParams }: PageProps<"/dashboard">) {
  const ctx = await requireStaff(["owner", "admin"]);
  const sp = await searchParams;
  const period = resolvePeriod(sp.p as string | undefined, ctx.today, sp.from as string | undefined, sp.to as string | undefined);
  const supabase = await createClient();
  const [kpiRes, monthly, risk, returned] = await Promise.all([
    supabase.rpc("dashboard_kpi", { p_gym: ctx.gym.id, p_from: period.from, p_to: period.to }),
    supabase.rpc("revenue_by_month", { p_gym: ctx.gym.id, p_months: 12 }),
    supabase.from("v_client_risk").select("reason").eq("gym_id", ctx.gym.id),
    supabase.rpc("risk_returned_stats", { p_gym: ctx.gym.id }),
  ]);
  if (kpiRes.error) return <Alert variant="danger">Не удалось загрузить дашборд: {kpiRes.error.message}</Alert>;
  const k = kpiRes.data as Dashboard;
  const c = k.current;
  const pv = k.previous;
  const riskCounts = (risk.data ?? []).reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.reason]: (acc[r.reason] ?? 0) + 1 }), {});
  const riskTotal = risk.data?.length ?? 0;
  const ret = (returned.data ?? { contacted: 0, returned: 0 }) as { contacted: number; returned: number };
  const prevLabel = `${date(k.previous_period.from)} – ${date(k.previous_period.to)}`;
  const occ = k.occupancy;

  return (
    <>
      <PageHeader
        title="Дашборд"
        description={`${date(k.period.from)} – ${date(k.period.to)} · сравнение с ${prevLabel}`}
        actions={<PeriodPicker current={period.key} from={period.from ?? k.period.from} to={period.to ?? k.period.to} />}
      />

      <div className="grid gap-4 lg:grid-cols-[1.3fr_1fr]">
        <Card variant="hero" className="flex flex-col justify-between gap-6 p-7">
          <div className="grid gap-2">
            <span className="text-sm text-muted-foreground">Выручка</span>
            <span className="text-5xl font-semibold tracking-tight sm:text-6xl">{money(c.revenue)}</span>
            <Delta current={c.revenue} previous={pv.revenue} format={money} goodWhenUp label="к прошлому периоду" />
          </div>
          <div>
            <p className="mb-2 text-xs text-muted-foreground">Выручка по месяцам, ₽</p>
            <ColumnChart
              data={((monthly.data ?? []) as { month: string; revenue: number }[]).map((m) => ({
                key: m.month,
                label: new Intl.DateTimeFormat("ru-RU", { month: "short", timeZone: "UTC" }).format(new Date(m.month.slice(0, 10) + "T00:00:00Z")).replace(".", ""),
                value: m.revenue / 100,
              }))}
              unit="₽"
              highlightLast
            />
          </div>
        </Card>

        <div className="grid grid-cols-2 gap-4">
          <Tile label="Активные клиенты" value={c.active_clients.toLocaleString("ru-RU")}
            delta={<Delta current={c.active_clients} previous={pv.active_clients} goodWhenUp />}
            hint="Абонемент действует или заморожен на конец периода" />
          <Tile label="Процент продления" value={c.renewal_rate === null ? "—" : `${Number(c.renewal_rate).toLocaleString("ru-RU")}%`}
            delta={c.renewal_rate !== null && pv.renewal_rate !== null ? <Delta current={c.renewal_rate} previous={pv.renewal_rate} goodWhenUp points /> : null}
            hint={`Продлили ${c.renewal_renewed} из ${c.renewal_ended} закончившихся`} />
          <Tile label="Отток" value={c.churn.toLocaleString("ru-RU")}
            delta={<Delta current={c.churn} previous={pv.churn} goodWhenUp={false} />}
            hint="Не продлили абонемент 14 дней" />
          <Tile label="Новые клиенты" value={c.new_clients.toLocaleString("ru-RU")}
            delta={<Delta current={c.new_clients} previous={pv.new_clients} goodWhenUp />}
            hint="Купили первый абонемент" />
        </div>
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-[1.3fr_1fr]">
        <Card>
          <CardHeader className="flex-row flex-wrap items-start justify-between gap-4">
            <div className="grid min-w-48 flex-1 gap-1">
              <CardTitle>Загруженность</CardTitle>
              <CardDescription>Среднее число людей в зале по дням недели и часам за 4 недели</CardDescription>
            </div>
            <div className="shrink-0 text-right">
              <p className="whitespace-nowrap text-3xl font-semibold tabular">{occ.now}{occ.capacity ? <span className="text-base font-normal text-muted-foreground"> / {occ.capacity}</span> : null}</p>
              <p className="text-xs text-muted-foreground">сейчас в зале{occ.load_pct !== null ? ` · ${occ.load_pct}%` : ""}</p>
            </div>
          </CardHeader>
          <CardContent>
            <Heatmap cells={occ.heatmap} hours={openHours(ctx.gym.settings?.hours)} />
          </CardContent>
        </Card>

        <div className="grid content-start gap-4">
          <Card>
            <CardHeader className="flex-row items-center justify-between">
              <CardTitle>В зоне риска</CardTitle>
              <Link href="/risk" className="flex items-center gap-1 text-sm font-medium hover:underline">{riskTotal} {plural(riskTotal, "клиент", "клиента", "клиентов")} <ArrowRight className="size-4" /></Link>
            </CardHeader>
            <CardContent className="grid gap-3">
              <div className="flex flex-wrap gap-2">
                {(["not_renewed", "expiring", "gone", "declining"] as RiskReason[]).map((r) => (
                  <Link key={r} href={`/risk?reason=${r}`} className="flex items-center gap-2 rounded-full bg-field py-1.5 pl-1.5 pr-3.5 text-sm hover:bg-field-hover">
                    <RiskBadge reason={r} /> <span className="font-semibold tabular">{riskCounts[r] ?? 0}</span>
                  </Link>
                ))}
              </div>
              <p className="text-sm text-muted-foreground">
                За 30 дней связались с <b className="text-foreground">{ret.contacted}</b>, вернулись{" "}
                <b className="text-foreground">{ret.returned}</b>{ret.contacted ? ` (${Math.round((ret.returned / ret.contacted) * 100)}%)` : ""}.
              </p>
            </CardContent>
          </Card>
          <Card>
            <CardHeader><CardTitle>Новые клиенты по источникам</CardTitle></CardHeader>
            <CardContent>
              {c.new_by_source.length ? (
                <BarList items={c.new_by_source.map((s) => ({ label: s.source, value: s.count }))} />
              ) : <p className="text-sm text-muted-foreground">За период новых клиентов нет</p>}
            </CardContent>
          </Card>
        </div>
      </div>
    </>
  );
}

function openHours(hours: Record<string, [string, string] | null> | undefined): [number, number] {
  const ranges = Object.values(hours ?? {}).filter(Boolean) as [string, string][];
  if (!ranges.length) return [6, 23];
  const start = Math.min(...ranges.map((r) => Number(r[0].slice(0, 2))));
  const end = Math.max(...ranges.map((r) => Math.min(23, Number(r[1].slice(0, 2)) - (r[1].endsWith(":00") ? 1 : 0))));
  return [start, Math.max(start, end)];
}

function Tile({ label, value, delta, hint }: { label: string; value: string; delta?: React.ReactNode; hint: string }) {
  return (
    <Card className="flex flex-col justify-between gap-3 p-5">
      <span className="text-sm text-muted-foreground">{label}</span>
      <div className="grid gap-1">
        <span className="text-3xl font-semibold tracking-tight">{value}</span>
        {delta}
      </div>
      <span className="text-xs text-muted-foreground">{hint}</span>
    </Card>
  );
}
