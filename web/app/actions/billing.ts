"use server";
import { requireStaff } from "@/lib/auth";
import { billingAvailable, billingKey, priceFor } from "@/lib/billing";
import { appOrigin } from "@/lib/origin";
import { stripeRequest, type CheckoutSession } from "@/lib/stripe";
import type { ActionResult } from "@/lib/errors";

const unavailable = { ok: false as const, error: { code: "FEATURE_DISABLED", message: "Онлайн-оплата подписки пока недоступна — напишите нам, выставим счёт" } };

/** Оплата подписки core. картой: Stripe Checkout в режиме подписки */
export async function startSubscription(): Promise<ActionResult<string>> {
  const ctx = await requireStaff(["owner"]);
  const key = billingKey();
  const price = priceFor(ctx.gym.core_plan);
  if (!key || !price || !billingAvailable(ctx.gym.region, ctx.gym.core_plan)) return unavailable;
  const origin = await appOrigin();
  try {
    const session = await stripeRequest<CheckoutSession>(key, "POST", "/v1/checkout/sessions", {
      mode: "subscription",
      line_items: [{ price, quantity: 1 }],
      client_reference_id: ctx.gym.id,
      metadata: { gym_id: ctx.gym.id },
      subscription_data: { metadata: { gym_id: ctx.gym.id } },
      customer: ctx.gym.stripe_customer_id ?? undefined,
      customer_email: ctx.gym.stripe_customer_id ? undefined : ctx.email ?? undefined,
      success_url: `${origin}/settings?billing=success`,
      cancel_url: `${origin}/settings`,
    });
    return { ok: true, data: session.url! };
  } catch (e) {
    console.error("billing checkout failed", e);
    return { ok: false, error: { code: "PAYMENT_PROVIDER_ERROR", message: "Не удалось открыть оплату. Попробуйте позже" } };
  }
}

/** Управление подпиской: карта, счета, отмена — в портале Stripe */
export async function manageSubscription(): Promise<ActionResult<string>> {
  const ctx = await requireStaff(["owner"]);
  const key = billingKey();
  if (!key || !ctx.gym.stripe_customer_id) return unavailable;
  try {
    const portal = await stripeRequest<{ url: string }>(key, "POST", "/v1/billing_portal/sessions", {
      customer: ctx.gym.stripe_customer_id, return_url: `${await appOrigin()}/settings`,
    });
    return { ok: true, data: portal.url };
  } catch (e) {
    console.error("billing portal failed", e);
    return { ok: false, error: { code: "PAYMENT_PROVIDER_ERROR", message: "Не удалось открыть оплату. Попробуйте позже" } };
  }
}
