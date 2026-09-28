"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { intOrNull, str, strOrNull } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import { parseRub } from "@/lib/format";
import type { PlanKind } from "@/lib/types";

export async function savePlan(form: FormData): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  const kind = str(form, "kind") as PlanKind;
  const price = parseRub(str(form, "price"));
  const row = {
    name: str(form, "name"),
    description: strOrNull(form, "description"),
    kind,
    price,
    duration_days: intOrNull(form, "duration_days"),
    visits_limit: kind === "visits" ? intOrNull(form, "visits_limit") : null,
    freeze_days_max: intOrNull(form, "freeze_days_max") ?? 0,
    sold_online: form.get("sold_online") === "on",
    active: form.get("active") !== "off",
  };
  if (!row.name) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите название тарифа" } };
  if (price === null) return { ok: false, error: { code: "INVALID_INPUT", message: "Цена — число в рублях, например 3000" } };
  if (!row.duration_days || row.duration_days <= 0) return { ok: false, error: { code: "INVALID_INPUT", message: "Срок действия — число дней больше нуля" } };
  if (kind === "visits" && !row.visits_limit) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите число визитов" } };
  const supabase = await createClient();
  const id = strOrNull(form, "id");
  const { error } = id
    ? await supabase.from("membership_plans").update(row).eq("id", id)
    : await supabase.from("membership_plans").insert({ ...row, gym_id: ctx.gym.id });
  if (error) return fail(error);
  revalidatePath("/plans");
  return ok(null);
}

export async function setPlanActive(id: string, active: boolean): Promise<ActionResult<null>> {
  await requireStaff(["owner"]);
  const supabase = await createClient();
  const { error } = await supabase.from("membership_plans").update({ active }).eq("id", id);
  if (error) return fail(error);
  revalidatePath("/plans");
  return ok(null);
}

export async function createTemplatePlans(templates: { name: string; kind: PlanKind; price: number; duration_days: number; visits_limit: number | null; freeze_days_max: number; sold_online: boolean }[]): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const { error } = await supabase.from("membership_plans").insert(templates.map((t) => ({ ...t, gym_id: ctx.gym.id })));
  if (error) return fail(error);
  revalidatePath("/plans");
  return ok(null);
}
