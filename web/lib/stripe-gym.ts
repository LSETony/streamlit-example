import "server-only";
import { createAdminClient } from "@/lib/supabase/admin";
import { decryptSecret } from "@/lib/secrets";
import { stripeRequest, type CheckoutSession } from "@/lib/stripe";

/*
  Оплаты абонементов через Stripe зала (ОАЭ). Деньги идут на Stripe-аккаунт зала; core. создаёт Checkout Session
  его ключом и активирует абонемент по уведомлению checkout.session.completed (идемпотентно, как для ЮKassa).
*/

export async function gymStripe(gymId: string): Promise<{ secret: string; webhookSecret: string | null } | null> {
  const { data } = await createAdminClient().from("gym_secrets")
    .select("stripe_secret_encrypted, stripe_webhook_secret_encrypted").eq("gym_id", gymId).maybeSingle();
  if (!data?.stripe_secret_encrypted) return null;
  return {
    secret: decryptSecret(data.stripe_secret_encrypted),
    webhookSecret: data.stripe_webhook_secret_encrypted ? decryptSecret(data.stripe_webhook_secret_encrypted) : null,
  };
}

export interface Purchase {
  payment_id: string; membership_id: string; gym_id: string; amount: number; description: string;
  client: { id: string; full_name: string; phone: string | null; email: string | null };
}

/** Checkout Session на сумму абонемента; ссылка живёт 24 часа */
export async function createGymCheckout(secret: string, purchase: Purchase, currency: string, origin: string): Promise<CheckoutSession> {
  const back = `${origin}/pay/done?payment=${purchase.payment_id}`;
  return stripeRequest<CheckoutSession>(secret, "POST", "/v1/checkout/sessions", {
    mode: "payment",
    line_items: [{ quantity: 1, price_data: { currency: currency.toLowerCase(), unit_amount: purchase.amount, product_data: { name: purchase.description } } }],
    client_reference_id: purchase.payment_id,
    metadata: { payment_id: purchase.payment_id, gym_id: purchase.gym_id },
    payment_intent_data: { metadata: { payment_id: purchase.payment_id, gym_id: purchase.gym_id } },
    customer_email: purchase.client.email ?? undefined,
    expires_at: Math.floor(Date.now() / 1000) + 24 * 3600,
    success_url: back,
    cancel_url: back,
  });
}

/** Возврат по платежу Checkout Session (полный или частичный, в минимальных единицах валюты) */
export async function refundGymCheckout(secret: string, sessionId: string, amount: number): Promise<{ id: string; status: string }> {
  const session = await stripeRequest<CheckoutSession>(secret, "GET", `/v1/checkout/sessions/${sessionId}`);
  if (!session.payment_intent) throw new Error("У сессии Stripe нет платежа");
  return stripeRequest<{ id: string; status: string }>(secret, "POST", "/v1/refunds", { payment_intent: session.payment_intent, amount });
}
