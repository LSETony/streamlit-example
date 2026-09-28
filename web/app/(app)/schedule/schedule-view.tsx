"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, Plus } from "lucide-react";
import { PageHeader } from "@/components/app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/client";
import { addDays, time, todayIn } from "@/lib/format";
import { cn } from "@/lib/utils";
import { CreateItemDialog } from "./create-item";
import { ItemDialog } from "./item-dialog";

export interface Item {
  id: string; title: string; kind: "class" | "personal" | "zone_slot"; zone_id: string | null; trainer_name: string | null;
  starts_at: string; ends_at: string; capacity: number; cancelled: boolean; series_id: string | null; description: string | null; booked: number;
}

const HOUR_PX = 64;
const WEEKDAYS = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
const KIND_STYLE = {
  class: "border-l-foreground bg-card",
  personal: "border-l-info bg-info/8",
  zone_slot: "border-l-brand bg-brand/12",
} as const;

function minutesOfDay(ts: string, tz: string): number {
  const [h, m] = time(ts, tz).split(":").map(Number);
  return h * 60 + m;
}

export function ScheduleView({ view, from, days, today, items, zones, gymId, timezone, canEdit, readOnly, hours }: {
  view: "week" | "day"; from: string; days: number; today: string; items: Item[]; zones: { id: string; name: string; capacity: number }[];
  gymId: string; timezone: string; canEdit: boolean; readOnly: boolean; hours?: Record<string, [string, string] | null>;
}) {
  const router = useRouter();
  const [create, setCreate] = useState<{ date: string; time: string } | null>(null);
  const [openId, setOpenId] = useState<string | null>(null);
  const [supabase] = useState(createClient);

  // Записи из приложения видны без перезагрузки (Realtime)
  useEffect(() => {
    const ch = supabase.channel(`schedule-${gymId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "bookings", filter: `gym_id=eq.${gymId}` }, () => router.refresh())
      .on("postgres_changes", { event: "*", schema: "public", table: "schedule_items", filter: `gym_id=eq.${gymId}` }, () => router.refresh())
      .subscribe();
    return () => { supabase.removeChannel(ch); };
  }, [supabase, gymId, router]);

  const [startHour, endHour] = useMemo(() => {
    const ranges = Object.values(hours ?? {}).filter(Boolean) as [string, string][];
    let s = ranges.length ? Math.min(...ranges.map((r) => Number(r[0].slice(0, 2)))) : 7;
    let e = ranges.length ? Math.max(...ranges.map((r) => Math.ceil(Number(r[1].slice(0, 2)) + Number(r[1].slice(3, 5)) / 60))) : 22;
    for (const i of items) {
      s = Math.min(s, Math.floor(minutesOfDay(i.starts_at, timezone) / 60));
      e = Math.max(e, Math.ceil(minutesOfDay(i.ends_at, timezone) / 60) || 24);
    }
    return [s, Math.min(24, Math.max(e, s + 1))];
  }, [hours, items, timezone]);

  const dayList = Array.from({ length: days }, (_, i) => addDays(from, i));
  const byDay = new Map<string, Item[]>();
  for (const i of items) {
    const d = todayIn(timezone, new Date(i.starts_at));
    byDay.set(d, [...(byDay.get(d) ?? []), i]);
  }
  const nav = (delta: number) => `/schedule?view=${view}&date=${addDays(from, delta * days)}`;
  const zoneName = (id: string | null) => zones.find((z) => z.id === id)?.name;
  const nowMin = minutesOfDay(new Date().toISOString(), timezone);
  const title = view === "week"
    ? `${new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long", timeZone: "UTC" }).format(new Date(from + "T00:00:00Z"))} – ${new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long", timeZone: "UTC" }).format(new Date(addDays(from, 6) + "T00:00:00Z"))}`
    : new Intl.DateTimeFormat("ru-RU", { weekday: "long", day: "numeric", month: "long", timeZone: "UTC" }).format(new Date(from + "T00:00:00Z"));

  return (
    <>
      <PageHeader
        title="Расписание"
        description={title}
        actions={
          <>
            <div className="flex rounded-lg border border-border bg-card p-0.5">
              {(["day", "week"] as const).map((v) => (
                <Link key={v} href={`/schedule?view=${v}&date=${v === "day" && view === "week" ? (dayList.includes(today) ? today : from) : from}`}
                  className={cn("rounded-md px-3 py-1.5 text-sm", view === v ? "bg-foreground text-background" : "text-muted-foreground hover:text-foreground")}>
                  {v === "day" ? "День" : "Неделя"}
                </Link>
              ))}
            </div>
            <Button variant="outline" size="icon" asChild><Link href={nav(-1)} aria-label="Назад"><ChevronLeft /></Link></Button>
            <Button variant="outline" asChild><Link href={`/schedule?view=${view}&date=${today}`}>Сегодня</Link></Button>
            <Button variant="outline" size="icon" asChild><Link href={nav(1)} aria-label="Вперёд"><ChevronRight /></Link></Button>
            {canEdit ? <Button onClick={() => setCreate({ date: dayList.includes(today) ? today : from, time: "19:00" })}><Plus /> Занятие</Button> : null}
          </>
        }
      />

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <div className="grid" style={{ gridTemplateColumns: `52px repeat(${days}, minmax(${days > 1 ? 130 : 240}px, 1fr))`, minWidth: days > 1 ? 52 + 130 * 7 : undefined }}>
            <div className="sticky left-0 z-10 border-b border-border bg-card" />
            {dayList.map((d, i) => (
              <Link key={d} href={`/schedule?view=day&date=${d}`}
                className={cn("border-b border-l border-border px-3 py-2 text-sm hover:bg-muted/40", d === today && "bg-muted/60")}>
                <span className="text-muted-foreground">{WEEKDAYS[(new Date(d + "T00:00:00Z").getUTCDay() + 6) % 7] ?? WEEKDAYS[i]}</span>{" "}
                <span className={cn("font-semibold", d === today && "rounded-md bg-brand px-1.5 text-brand-foreground")}>{Number(d.slice(8))}</span>
              </Link>
            ))}

            <div className="relative sticky left-0 z-10 bg-card" style={{ height: (endHour - startHour) * HOUR_PX }}>
              {Array.from({ length: endHour - startHour }, (_, h) => (
                <span key={h} className="absolute right-2 -translate-y-1/2 text-[11px] text-muted-foreground tabular" style={{ top: h * HOUR_PX }}>
                  {h === 0 ? "" : `${String(startHour + h).padStart(2, "0")}:00`}
                </span>
              ))}
            </div>
            {dayList.map((d) => (
              <div key={d} className="relative border-l border-border" style={{ height: (endHour - startHour) * HOUR_PX }}
                onDoubleClick={(e) => {
                  if (!canEdit) return;
                  const y = e.clientY - (e.currentTarget as HTMLElement).getBoundingClientRect().top;
                  const h = startHour + Math.floor(y / HOUR_PX);
                  setCreate({ date: d, time: `${String(h).padStart(2, "0")}:00` });
                }}>
                {Array.from({ length: endHour - startHour }, (_, h) => (
                  <div key={h} className="absolute inset-x-0 border-t border-border/60" style={{ top: h * HOUR_PX }} />
                ))}
                {d === today && nowMin >= startHour * 60 && nowMin <= endHour * 60 ? (
                  <div className="absolute inset-x-0 z-20 h-0.5 bg-destructive" style={{ top: ((nowMin - startHour * 60) / 60) * HOUR_PX }} aria-hidden />
                ) : null}
                {layout(byDay.get(d) ?? [], timezone).map(({ item: i, col, cols }) => {
                  const top = ((minutesOfDay(i.starts_at, timezone) - startHour * 60) / 60) * HOUR_PX;
                  const height = Math.max(26, ((new Date(i.ends_at).getTime() - new Date(i.starts_at).getTime()) / 3600000) * HOUR_PX - 2);
                  const full = i.booked >= i.capacity;
                  return (
                    <button
                      key={i.id}
                      type="button"
                      title={`${i.title} · ${time(i.starts_at, timezone)}${i.trainer_name ? ` · ${i.trainer_name}` : ""}${zoneName(i.zone_id) ? ` · ${zoneName(i.zone_id)}` : ""} · ${i.booked}/${i.capacity}`}
                      onClick={() => setOpenId(i.id)}
                      className={cn(
                        "absolute z-10 cursor-pointer overflow-hidden rounded-lg border border-border border-l-[3px] px-2 py-1 text-left text-xs shadow-sm transition-shadow hover:shadow-md",
                        KIND_STYLE[i.kind], i.cancelled && "opacity-50 line-through",
                      )}
                      style={{ top: top + 1, height, left: `calc(${(col / cols) * 100}% + 2px)`, width: `calc(${100 / cols}% - 4px)` }}
                    >
                      <span className="block truncate font-semibold">{i.title}</span>
                      <span className="flex items-center gap-1.5 truncate text-muted-foreground">
                        <span className="tabular">{time(i.starts_at, timezone)}</span>
                        <span className={cn("rounded px-1 tabular", full ? "bg-destructive/15 text-destructive" : "bg-muted text-foreground")}>{i.booked}/{i.capacity}</span>
                        {height > 50 ? null : <span className="truncate">{i.trainer_name ?? ""}</span>}
                      </span>
                      {height > 50 ? (
                        <span className="block truncate text-muted-foreground">{[i.trainer_name, zoneName(i.zone_id)].filter(Boolean).join(" · ")}</span>
                      ) : null}
                    </button>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      </Card>
      <p className="mt-2 text-xs text-muted-foreground">
        {canEdit ? "Двойной клик по сетке — новое занятие в это время. " : ""}Записи из приложения появляются автоматически.
      </p>

      {create ? (
        <CreateItemDialog gymZones={zones} initialDate={create.date} initialTime={create.time} onClose={() => { setCreate(null); router.refresh(); }} />
      ) : null}
      {openId ? (
        <ItemDialog
          item={items.find((i) => i.id === openId)!}
          zones={zones}
          gymId={gymId}
          timezone={timezone}
          canEdit={canEdit}
          readOnly={readOnly}
          onClose={() => { setOpenId(null); router.refresh(); }}
        />
      ) : null}
    </>
  );
}

/** Раскладка пересекающихся занятий по колонкам */
function layout(items: Item[], tz: string): { item: Item; col: number; cols: number }[] {
  const sorted = [...items].sort((a, b) => a.starts_at.localeCompare(b.starts_at));
  const out: { item: Item; col: number; cols: number }[] = [];
  let group: { item: Item; col: number }[] = [];
  let groupEnd = -1;
  const flush = () => {
    const cols = Math.max(1, ...group.map((g) => g.col + 1));
    group.forEach((g) => out.push({ ...g, cols }));
    group = [];
  };
  for (const item of sorted) {
    const s = minutesOfDay(item.starts_at, tz);
    const e = s + (new Date(item.ends_at).getTime() - new Date(item.starts_at).getTime()) / 60000;
    if (s >= groupEnd) { flush(); groupEnd = -1; }
    const used = new Set(group.filter((g) => {
      const gs = minutesOfDay(g.item.starts_at, tz);
      const ge = gs + (new Date(g.item.ends_at).getTime() - new Date(g.item.starts_at).getTime()) / 60000;
      return gs < e && ge > s;
    }).map((g) => g.col));
    let col = 0;
    while (used.has(col)) col++;
    group.push({ item, col });
    groupEnd = Math.max(groupEnd, e);
  }
  flush();
  return out;
}
