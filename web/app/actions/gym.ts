"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { callRpc, intOrNull, str, strOrNull } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import { encryptSecret } from "@/lib/secrets";
import type { GymSettings } from "@/lib/types";
import { isRegion, REGIONS } from "@/lib/region";

export async function createGym(form: FormData): Promise<ActionResult<string>> {
  const name = str(form, "name");
  const owner = str(form, "owner_name");
  if (!name || !owner) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите название зала и ваше имя" } };
  const region = str(form, "region");
  if (!isRegion(region)) return { ok: false, error: { code: "INVALID_REGION", message: "Выберите регион: Россия или ОАЭ" } };
  return callRpc<string>("create_gym", {
    p_name: name,
    p_owner_name: owner,
    p_address: strOrNull(form, "address"),
    p_timezone: str(form, "timezone") || REGIONS[region].timezone,
    p_phone: strOrNull(form, "phone"),
    // регион передаём только для ОАЭ: российские залы создаются и на базе без миграции регионов
    ...(region === "RU" ? {} : { p_region: region }),
  });
}

export async function updateGymProfile(form: FormData): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const { error } = await supabase.from("gyms").update({
    name: str(form, "name"),
    address: strOrNull(form, "address"),
    phone: strOrNull(form, "phone"),
    timezone: str(form, "timezone") || ctx.gym.timezone,
  }).eq("id", ctx.gym.id);
  if (error) return fail(error);
  revalidatePath("/", "layout");
  return ok(null);
}

/** Частичное обновление настроек зала (jsonb settings) */
export async function updateGymSettings(patch: Partial<GymSettings>): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const settings = { ...ctx.gym.settings, ...patch };
  const { error } = await supabase.from("gyms").update({ settings }).eq("id", ctx.gym.id);
  if (error) return fail(error);
  revalidatePath("/", "layout");
  return ok(null);
}

export async function finishOnboarding(): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const { error } = await supabase.from("gyms").update({ onboarded_at: new Date().toISOString() }).eq("id", ctx.gym.id);
  if (error) return fail(error);
  revalidatePath("/", "layout");
  return ok(null);
}

export async function saveZone(form: FormData): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner", "admin"]);
  const supabase = await createClient();
  const id = strOrNull(form, "id");
  const row = { name: str(form, "name"), capacity: intOrNull(form, "capacity") ?? 10 };
  if (!row.name) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите название зоны" } };
  const { error } = id
    ? await supabase.from("zones").update(row).eq("id", id)
    : await supabase.from("zones").insert({ ...row, gym_id: ctx.gym.id });
  if (error) return fail(error);
  revalidatePath("/settings");
  revalidatePath("/schedule");
  return ok(null);
}

export async function deleteZone(id: string): Promise<ActionResult<null>> {
  await requireStaff(["owner", "admin"]);
  const supabase = await createClient();
  const { error } = await supabase.from("zones").delete().eq("id", id);
  if (error) return fail(error);
  revalidatePath("/settings");
  return ok(null);
}

/** Ключи магазина ЮKassa зала: секрет шифруется и хранится только на сервере */
export async function saveYookassa(form: FormData): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  if (ctx.readOnly) return { ok: false, error: { code: "GYM_READ_ONLY", message: "Кабинет в режиме «только чтение»" } };
  if (!REGIONS[ctx.gym.region ?? "RU"].onlinePayments) return { ok: false, error: { code: "FEATURE_DISABLED", message: "ЮKassa работает только для залов в России" } };
  const shopId = str(form, "shop_id");
  const secret = str(form, "secret_key");
  if (!/^\d+$/.test(shopId)) return { ok: false, error: { code: "INVALID_INPUT", message: "shopId — это число из личного кабинета ЮKassa" } };
  const admin = createAdminClient();
  const row: Record<string, unknown> = {
    gym_id: ctx.gym.id,
    yookassa_shop_id: shopId,
    yookassa_send_receipt: form.get("send_receipt") === "on",
    vat_code: intOrNull(form, "vat_code") ?? 1,
    updated_at: new Date().toISOString(),
  };
  if (secret) row.yookassa_secret_encrypted = encryptSecret(secret);
  const { error } = await admin.from("gym_secrets").upsert(row);
  if (error) return fail(error);
  revalidatePath("/settings");
  return ok(null);
}

export async function yookassaStatus(): Promise<{ connected: boolean; shopId: string | null; sendReceipt: boolean; vatCode: number }> {
  const ctx = await requireStaff(["owner"]);
  try {
    const { data } = await createAdminClient().from("gym_secrets")
      .select("yookassa_shop_id, yookassa_secret_encrypted, yookassa_send_receipt, vat_code").eq("gym_id", ctx.gym.id).maybeSingle();
    return {
      connected: Boolean(data?.yookassa_shop_id && data?.yookassa_secret_encrypted),
      shopId: data?.yookassa_shop_id ?? null,
      sendReceipt: data?.yookassa_send_receipt ?? true,
      vatCode: data?.vat_code ?? 1,
    };
  } catch {
    return { connected: false, shopId: null, sendReceipt: true, vatCode: 1 };
  }
}
