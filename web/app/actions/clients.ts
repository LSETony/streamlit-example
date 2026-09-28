"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callRpc, str, strOrNull } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import { normalizePhone } from "@/lib/phone";

const CONSENT_PD_TEXT = "Согласие на обработку персональных данных получено залом (отметка в кабинете core.)";
const CONSENT_MARKETING_TEXT = "Согласие на получение рассылок получено залом (отметка в кабинете core.)";

export interface DuplicateClient { id: string; full_name: string }

/** FR-2.2 Проверка дубля по телефону */
export async function findByPhone(rawPhone: string): Promise<DuplicateClient | null> {
  const ctx = await requireStaff();
  const phone = normalizePhone(rawPhone);
  if (!phone) return null;
  const supabase = await createClient();
  const { data } = await supabase.from("clients").select("id, full_name")
    .eq("gym_id", ctx.gym.id).eq("phone", phone).is("deleted_at", null).maybeSingle();
  return data ?? null;
}

/** FR-2.2 Создание клиента: ФИО, телефон, источник, согласие на обработку данных */
export async function createClientAction(form: FormData): Promise<ActionResult<{ id: string }>> {
  const ctx = await requireStaff();
  const phone = normalizePhone(str(form, "phone"));
  if (!str(form, "full_name")) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите ФИО" } };
  if (!phone) return { ok: false, error: { code: "INVALID_PHONE", message: "Некорректный номер телефона" } };
  if (form.get("consent_pd") !== "on") {
    return { ok: false, error: { code: "CONSENT_REQUIRED", message: "Отметьте согласие клиента на обработку персональных данных" } };
  }
  const dup = await findByPhone(phone);
  if (dup) return { ok: false, error: { code: "DUPLICATE_PHONE", message: `Клиент с этим телефоном уже есть: ${dup.full_name}` } };
  const now = new Date().toISOString();
  const marketing = form.get("consent_marketing") === "on";
  const supabase = await createClient();
  const { data, error } = await supabase.from("clients").insert({
    gym_id: ctx.gym.id,
    full_name: str(form, "full_name"),
    phone,
    email: strOrNull(form, "email"),
    birth_date: strOrNull(form, "birth_date"),
    gender: strOrNull(form, "gender"),
    source: strOrNull(form, "source"),
    note: strOrNull(form, "note"),
    tags: str(form, "tags").split(",").map((t) => t.trim()).filter(Boolean),
    consent_pd_at: now,
    consent_pd_text: CONSENT_PD_TEXT,
    consent_marketing_at: marketing ? now : null,
    consent_marketing_text: marketing ? CONSENT_MARKETING_TEXT : null,
  }).select("id").single();
  if (error) return fail(error);
  revalidatePath("/clients");
  return ok({ id: data.id });
}

export async function updateClientAction(id: string, form: FormData): Promise<ActionResult<null>> {
  await requireStaff();
  const phone = normalizePhone(str(form, "phone"));
  if (!phone) return { ok: false, error: { code: "INVALID_PHONE", message: "Некорректный номер телефона" } };
  const supabase = await createClient();
  const { data: current } = await supabase.from("clients").select("consent_marketing_at").eq("id", id).single();
  const marketing = form.get("consent_marketing") === "on";
  const { error } = await supabase.from("clients").update({
    full_name: str(form, "full_name"),
    phone,
    email: strOrNull(form, "email"),
    birth_date: strOrNull(form, "birth_date"),
    gender: strOrNull(form, "gender"),
    source: strOrNull(form, "source"),
    note: strOrNull(form, "note"),
    tags: str(form, "tags").split(",").map((t) => t.trim()).filter(Boolean),
    consent_marketing_at: marketing ? (current?.consent_marketing_at ?? new Date().toISOString()) : null,
    consent_marketing_text: marketing ? CONSENT_MARKETING_TEXT : null,
  }).eq("id", id);
  if (error) {
    if (error.code === "23505") return { ok: false, error: { code: "DUPLICATE_PHONE", message: "Этот телефон уже у другого клиента" } };
    return fail(error);
  }
  revalidatePath(`/clients/${id}`);
  return ok(null);
}

export async function saveNote(id: string, note: string): Promise<ActionResult<null>> {
  await requireStaff();
  const supabase = await createClient();
  const { error } = await supabase.from("clients").update({ note: note.trim() || null }).eq("id", id);
  if (error) return fail(error);
  revalidatePath(`/clients/${id}`);
  return ok(null);
}

/** FR-2.6 Удаление по запросу клиента — обезличивание */
export async function anonymizeClient(id: string): Promise<ActionResult<null>> {
  await requireStaff(["owner", "admin"]);
  const res = await callRpc<null>("anonymize_client", { p_client: id });
  if (res.ok) revalidatePath("/clients");
  return res;
}

export interface ImportRow {
  row: number;
  full_name: string;
  phone: string;
  email?: string | null;
  birth_date?: string | null;
  gender?: string | null;
  source?: string | null;
  tags?: string[];
  note?: string | null;
  plan_name?: string | null;
  starts_on?: string | null;
  ends_on?: string | null;
  visits_left?: number | null;
}

export interface ImportReport {
  created: number;
  updated: number;
  memberships: number;
  errors: { row: number; error: string }[];
  total: number;
}

/** FR-2.4 Импорт пачки строк (кабинет режет файл на пачки по 500) */
export async function importChunk(rows: ImportRow[], consent: boolean): Promise<ActionResult<ImportReport>> {
  const ctx = await requireStaff(["owner", "admin"]);
  const res = await callRpc<ImportReport>("import_clients", { p_gym: ctx.gym.id, p_rows: rows, p_consent: consent });
  if (res.ok) revalidatePath("/clients");
  return res;
}
