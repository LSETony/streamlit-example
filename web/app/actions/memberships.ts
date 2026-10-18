"use server";
import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callRpc } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import type { PaymentMethod } from "@/lib/types";
import { REGIONS } from "@/lib/region";
import { createAdminClient } from "@/lib/supabase/admin";
import { appOrigin } from "@/lib/origin";
import { createGymCheckout, gymStripe, refundGymCheckout, type Purchase } from "@/lib/stripe-gym";

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

/** FR-6.2 Ссылка на онлайн-оплату из кабинета: ЮKassa (Edge Function payments) или Stripe зала (ОАЭ) */
export async function createPaymentLink(input: {
  clientId: string; planId: string; startsOn?: string | null; renewFrom?: string | null;
}): Promise<ActionResult<{ confirmation_url: string | null; payment_id: string }>> {
  const ctx = await requireStaff();
  const region = REGIONS[ctx.gym.region ?? "RU"];
  if (!region.onlinePayments) {
    return { ok: false, error: { code: "FEATURE_DISABLED", message: "Онлайн-оплата недоступна для региона зала" } };
  }
  const supabase = await createClient();
  if (region.paymentProvider === "stripe") return stripePaymentLink(ctx.gym.id, region.currency, input);
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

async function stripePaymentLink(gymId: string, currency: string, input: {
  clientId: string; planId: string; startsOn?: string | null; renewFrom?: string | null;
}): Promise<ActionResult<{ confirmation_url: string | null; payment_id: string }>> {
  const keys = await gymStripe(gymId);
  if (!keys) return { ok: false, error: { code: "STRIPE_NOT_CONNECTED", message: "Stripe не подключён. Подключите его в настройках зала" } };
  const started = await callRpc<Purchase>("start_online_purchase", {
    p_plan: input.planId, p_client: input.clientId, p_starts_on: input.startsOn || null, p_renew_from: input.renewFrom || null,
  });
  if (!started.ok) return started;
  const purchase = started.data;
  const admin = createAdminClient();
  try {
    await admin.from("payments").update({ provider: "stripe" }).eq("id", purchase.payment_id);
    const session = await createGymCheckout(keys.secret, purchase, currency, await appOrigin());
    const { error } = await admin.rpc("attach_provider_payment", {
      p_payment: purchase.payment_id, p_provider_payment_id: session.id, p_confirmation_url: session.url,
    });
    if (error) throw error;
    touch(input.clientId);
    return ok({ confirmation_url: session.url, payment_id: purchase.payment_id });
  } catch (e) {
    // платёж не создан в Stripe — снимаем «висящие» записи сразу
    await admin.from("payments").update({ status: "failed" }).eq("id", purchase.payment_id).eq("status", "pending");
    await admin.from("memberships").update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", purchase.membership_id).eq("status", "pending");
    console.error("stripe checkout failed", e);
    return { ok: false, error: { code: "PAYMENT_PROVIDER_ERROR", message: "Stripe не создал платёж. Проверьте ключ в настройках или примите оплату на кассе" } };
  }
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
    const { data: pay } = await supabase.from("payments").select("provider, gym_id").eq("id", input.paymentId).maybeSingle();
    if (pay?.provider === "stripe") return refundStripe(pay.gym_id, input);
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

async function refundStripe(gymId: string, input: {
  paymentId: string; amount: number | null; cancelMembership: boolean; reason?: string; clientId?: string;
}): Promise<ActionResult<{ status: string }>> {
  const keys = await gymStripe(gymId);
  if (!keys) return { ok: false, error: { code: "STRIPE_NOT_CONNECTED", message: "Stripe не подключён. Подключите его в настройках зала" } };
  const r = await callRpc<{ refund_id: string; amount: number; status: string; needs_provider: boolean; provider_payment_id: string | null }>("refund_payment", {
    p_payment: input.paymentId, p_amount: input.amount, p_cancel_membership: input.cancelMembership, p_reason: input.reason || null,
  });
  if (!r.ok) return r;
  touch(input.clientId);
  if (!r.data.needs_provider || !r.data.provider_payment_id) return ok({ status: r.data.status });
  const admin = createAdminClient();
  try {
    const refund = await refundGymCheckout(keys.secret, r.data.provider_payment_id, r.data.amount);
    await admin.from("payments").update({ provider_payment_id: refund.id }).eq("id", r.data.refund_id);
    if (refund.status === "succeeded" || refund.status === "failed" || refund.status === "canceled") {
      await admin.rpc("confirm_refund", { p_refund: r.data.refund_id, p_succeeded: refund.status === "succeeded", p_provider_refund_id: refund.id });
    }
    return ok({ status: refund.status === "succeeded" ? "refunded" : refund.status === "pending" ? "pending" : "failed" });
  } catch (e) {
    await admin.rpc("confirm_refund", { p_refund: r.data.refund_id, p_succeeded: false, p_provider_refund_id: null });
    console.error("stripe refund failed", e);
    return { ok: false, error: { code: "PAYMENT_PROVIDER_ERROR", message: "Stripe не выполнил возврат. Попробуйте позже" } };
  }
}
