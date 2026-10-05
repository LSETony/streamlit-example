"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callRpc } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import type { PaymentMethod } from "@/lib/types";
import { REGIONS } from "@/lib/region";

function touch(clientId?: string) {
  if (clientId) revalidatePath(`/clients/${clientId}`);
  revalidatePath("/clients");
  revalidatePath("/payments");
}

/** FR-3.2 / FR-3.3 Продажа или продление за наличные/картой */
export async function sellMembership(input: {
  clientId: string; planId: string; method: Exclude<PaymentMethod, "online">; startsOn?: string | null; renewFrom?: string | null;
}): Promise<ActionResult<{ membership: { id: string; ends_on: string; starts_on: string }; payment_id: string | null }>> {
  await requireStaff();
  const res = await callRpc<{ membership: { id: string; ends_on: string; starts_on: string }; payment_id: string | null }>("sell_membership", {
    p_client: input.clientId,
    p_plan: input.planId,
    p_method: input.method,
    p_starts_on: input.startsOn || null,
    p_renew_from: input.renewFrom || null,
  });
  if (res.ok) touch(input.clientId);
  return res;
}

/** FR-6.2 Ссылка на онлайн-оплату из кабинета (Edge Function payments → ЮKassa) */
export async function createPaymentLink(input: {
  clientId: string; planId: string; startsOn?: string | null; renewFrom?: string | null;
}): Promise<ActionResult<{ confirmation_url: string | null; payment_id: string }>> {
  const ctx = await requireStaff();
  if (!REGIONS[ctx.gym.region ?? "RU"].onlinePayments) {
    return { ok: false, error: { code: "FEATURE_DISABLED", message: "Онлайн-оплата пока доступна только для залов в России" } };
  }
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke("payments", {
    body: {
      plan_id: input.planId,
      client_id: input.clientId,
      starts_on: input.startsOn || undefined,
      renew_from: input.renewFrom || undefined,
      mode: "redirect",
    },
  });
  if (error) return fail(await functionError(error));
  touch(input.clientId);
  return ok(data as { confirmation_url: string | null; payment_id: string });
}

async function functionError(error: unknown): Promise<unknown> {
  // FunctionsHttpError содержит тело ответа {code, message}
  const ctx = (error as { context?: Response }).context;
  if (ctx && typeof ctx.json === "function") {
    try {
      const body = await ctx.json();
      if (body?.message) return { code: "P0001", hint: body.code, message: body.message };
    } catch {
      /* тело не JSON */
    }
  }
  return { message: "Сервис онлайн-оплаты недоступен. Попробуйте позже или примите оплату на кассе" };
}

/** FR-3.4 Заморозка */
export async function freezeMembership(input: { membershipId: string; clientId: string; from: string; to: string; reason?: string }): Promise<ActionResult<unknown>> {
  await requireStaff();
  const res = await callRpc("freeze_membership", { p_membership: input.membershipId, p_from: input.from, p_to: input.to, p_reason: input.reason || null });
  if (res.ok) touch(input.clientId);
  return res;
}

export async function endFreeze(freezeId: string, clientId: string): Promise<ActionResult<unknown>> {
  await requireStaff();
  const res = await callRpc("end_freeze", { p_freeze: freezeId });
  if (res.ok) touch(clientId);
  return res;
}

export async function cancelMembership(membershipId: string, clientId: string): Promise<ActionResult<unknown>> {
  await requireStaff(["owner", "admin"]);
  const res = await callRpc("cancel_membership", { p_membership: membershipId });
  if (res.ok) touch(clientId);
  return res;
}

/** FR-6.3 / FR-3.6 Возврат полной или частичной суммы; онлайн — через ЮKassa */
export async function refundPayment(input: {
  paymentId: string; amount: number | null; cancelMembership: boolean; reason?: string; online: boolean; clientId?: string;
}): Promise<ActionResult<{ status: string }>> {
  await requireStaff(["owner", "admin"]);
  if (input.online) {
    const supabase = await createClient();
    const { data, error } = await supabase.functions.invoke("payments/refund", {
      body: { payment_id: input.paymentId, amount: input.amount ?? undefined, cancel_membership: input.cancelMembership, reason: input.reason },
    });
    if (error) return fail(await functionError(error));
    touch(input.clientId);
    return ok(data as { status: string });
  }
  const res = await callRpc<{ status: string }>("refund_payment", {
    p_payment: input.paymentId, p_amount: input.amount, p_cancel_membership: input.cancelMembership, p_reason: input.reason || null,
  });
  if (res.ok) touch(input.clientId);
  return res;
}
