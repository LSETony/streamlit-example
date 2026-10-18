"use server";
import { revalidatePath } from "next/cache";
import { callRpc } from "@/lib/actions";
import type { ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { decryptSecret } from "@/lib/secrets";
import { sendWhatsappTemplate } from "@/lib/whatsapp";

/** FR-8.2 Отметить «связались» (и отправить push, если канал push) */
export async function markContacted(input: {
  clientId: string; reason: string; channel: "call" | "telegram" | "whatsapp" | "push" | "other"; note?: string; pushText?: string;
}): Promise<ActionResult<string>> {
  await requireStaff();
  const res = await callRpc<string>("mark_contacted", {
    p_client: input.clientId, p_reason: input.reason, p_channel: input.channel, p_note: input.note || null, p_push_text: input.pushText || null,
  });
  if (res.ok) revalidatePath("/risk");
  return res;
}

/** Отправка шаблона WhatsApp выбранным клиентам «в зоне риска» (только с согласием на рассылки) и отметка контакта */
export async function sendWhatsappToRisk(items: { clientId: string; reason: string }[]): Promise<ActionResult<{ sent: number; failed: number; skipped: number; firstError: string | null }>> {
  const ctx = await requireStaff(["owner", "admin"]);
  if (ctx.readOnly) return { ok: false, error: { code: "GYM_READ_ONLY", message: "Кабинет в режиме «только чтение»" } };
  const admin = createAdminClient();
  const { data: sec } = await admin.from("gym_secrets")
    .select("whatsapp_phone_id, whatsapp_token_encrypted, whatsapp_template, whatsapp_lang").eq("gym_id", ctx.gym.id).maybeSingle();
  if (!sec?.whatsapp_phone_id || !sec.whatsapp_token_encrypted || !sec.whatsapp_template) {
    return { ok: false, error: { code: "WHATSAPP_NOT_CONNECTED", message: "WhatsApp Business не подключён. Подключите его в настройках зала" } };
  }
  const cfg = { phoneId: sec.whatsapp_phone_id, token: decryptSecret(sec.whatsapp_token_encrypted), template: sec.whatsapp_template, lang: sec.whatsapp_lang ?? "en" };
  const ids = items.slice(0, 200).map((i) => i.clientId);
  const supabase = await createClient();
  const { data: clients } = await supabase.from("clients").select("id, full_name, phone, consent_marketing_at")
    .eq("gym_id", ctx.gym.id).in("id", ids);
  const byId = new Map((clients ?? []).map((c) => [c.id, c]));
  let sent = 0, failed = 0, skipped = 0;
  let firstError: string | null = null;
  for (const item of items.slice(0, 200)) {
    const c = byId.get(item.clientId);
    if (!c?.phone || !c.consent_marketing_at) { skipped++; continue; }
    const firstName = ctx.gym.region === "AE" ? c.full_name.split(" ")[0] : (c.full_name.split(" ")[1] ?? c.full_name);
    const r = await sendWhatsappTemplate(cfg, c.phone, [firstName, ctx.gym.name]);
    if (!r.ok) { failed++; firstError ??= r.error; continue; }
    sent++;
    await callRpc("mark_contacted", { p_client: c.id, p_reason: item.reason, p_channel: "whatsapp", p_note: "WhatsApp Business", p_push_text: null });
  }
  revalidatePath("/risk");
  return { ok: true, data: { sent, failed, skipped, firstError } };
}
