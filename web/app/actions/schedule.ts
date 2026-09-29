"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callRpc } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";

export interface SeriesInput {
  title: string;
  kind: "class" | "personal" | "zone_slot";
  date: string;          // YYYY-MM-DD (по времени зала)
  time: string;          // HH:MM
  durationMin: number;
  capacity: number;
  zoneId: string | null;
  trainer: string | null;
  weekdays: number[];    // 1 = пн … 7 = вс; пусто — разовое занятие
  until: string | null;
  description: string | null;
}

/** FR-5.2 Разовое или повторяющееся занятие */
export async function createSeries(input: SeriesInput): Promise<ActionResult<{ created: number }>> {
  const ctx = await requireStaff(["owner", "admin"]);
  if (!input.title.trim()) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите название" } };
  const res = await callRpc<{ created: number }>("create_schedule_series", {
    p_gym: ctx.gym.id,
    p_title: input.title.trim(),
    p_starts_local: `${input.date}T${input.time}:00`,
    p_duration_min: input.durationMin,
    p_capacity: input.capacity,
    p_kind: input.kind,
    p_zone: input.zoneId,
    p_trainer: input.trainer,
    p_weekdays: input.weekdays.length ? input.weekdays : null,
    p_until: input.until,
    p_description: input.description,
  });
  if (res.ok) revalidatePath("/schedule");
  return res;
}

/** Изменение занятия (или всех будущих занятий серии): название, тренер, вместимость, зона */
export async function updateItem(input: {
  id: string; seriesId: string | null; applyToSeries: boolean; startsAt: string;
  title: string; trainer: string | null; capacity: number; zoneId: string | null;
}): Promise<ActionResult<null>> {
  await requireStaff(["owner", "admin"]);
  const supabase = await createClient();
  const patch = { title: input.title, trainer_name: input.trainer, capacity: input.capacity, zone_id: input.zoneId };
  const q = supabase.from("schedule_items").update(patch);
  const { error } = input.applyToSeries && input.seriesId
    ? await q.eq("series_id", input.seriesId).gte("starts_at", input.startsAt).eq("cancelled", false)
    : await q.eq("id", input.id);
  if (error) return fail(error);
  revalidatePath("/schedule");
  return ok(null);
}

export async function cancelClass(id: string, reason: string | null): Promise<ActionResult<{ notified: number }>> {
  await requireStaff(["owner", "admin"]);
  const res = await callRpc<{ notified: number }>("cancel_class", { p_item: id, p_reason: reason });
  if (res.ok) revalidatePath("/schedule");
  return res;
}

export async function bookClient(itemId: string, clientId: string): Promise<ActionResult<{ booking_id: string; spots_left: number }>> {
  await requireStaff();
  const res = await callRpc<{ booking_id: string; spots_left: number }>("book_class", { p_item: itemId, p_client: clientId });
  if (res.ok) revalidatePath("/schedule");
  return res;
}

export async function cancelBooking(bookingId: string): Promise<ActionResult<null>> {
  await requireStaff();
  const res = await callRpc<null>("cancel_booking", { p_booking: bookingId });
  if (res.ok) revalidatePath("/schedule");
  return res;
}

export async function markBooking(bookingId: string, status: "attended" | "no_show" | "booked"): Promise<ActionResult<null>> {
  await requireStaff();
  const res = await callRpc<null>("mark_booking", { p_booking: bookingId, p_status: status });
  if (res.ok) revalidatePath("/schedule");
  return res;
}
