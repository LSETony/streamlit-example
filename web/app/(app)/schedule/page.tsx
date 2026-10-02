import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { addDays, zonedToUtc } from "@/lib/format";
import { ScheduleView, type Item } from "./schedule-view";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Расписание") };
}

function mondayOf(d: string): string {
  const [y, m, day] = d.split("-").map(Number);
  const dow = (new Date(Date.UTC(y, m - 1, day)).getUTCDay() + 6) % 7;
  return addDays(d, -dow);
}

export default async function SchedulePage({ searchParams }: PageProps<"/schedule">) {
  const ctx = await requireStaff();
  const sp = await searchParams;
  const view = sp.view === "day" ? "day" : "week";
  const anchor = typeof sp.date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(sp.date) ? sp.date : ctx.today;
  const from = view === "week" ? mondayOf(anchor) : anchor;
  const days = view === "week" ? 7 : 1;
  const tz = ctx.gym.timezone;

  const supabase = await createClient();
  const [{ data: items }, { data: zones }] = await Promise.all([
    supabase.from("schedule_items").select("*, bookings(status)")
      .eq("gym_id", ctx.gym.id)
      .gte("starts_at", zonedToUtc(from, "00:00", tz).toISOString())
      .lt("starts_at", zonedToUtc(addDays(from, days), "00:00", tz).toISOString())
      .order("starts_at"),
    supabase.from("zones").select("id, name, capacity").eq("gym_id", ctx.gym.id).order("name"),
  ]);

  const list: Item[] = (items ?? []).map((i) => ({
    id: i.id, title: i.title, kind: i.kind, zone_id: i.zone_id, trainer_name: i.trainer_name, starts_at: i.starts_at, ends_at: i.ends_at,
    capacity: i.capacity, cancelled: i.cancelled, series_id: i.series_id, description: i.description,
    booked: ((i.bookings ?? []) as { status: string }[]).filter((b) => b.status === "booked" || b.status === "attended").length,
  }));

  return (
    <ScheduleView
      view={view}
      viewChosen={sp.view === "day" || sp.view === "week"}
      from={from}
      days={days}
      today={ctx.today}
      items={list}
      zones={(zones ?? []) as { id: string; name: string; capacity: number }[]}
      gymId={ctx.gym.id}
      timezone={tz}
      canEdit={ctx.staff.role !== "reception" && !ctx.readOnly}
      readOnly={ctx.readOnly}
      hours={ctx.gym.settings?.hours}
    />
  );
}
