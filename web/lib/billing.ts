import "server-only";

/*
  Подписка core. через Stripe-аккаунт core. (залы в ОАЭ). Цены создаются в Stripe и задаются переменными
  STRIPE_PRICE_START / STRIPE_PRICE_BUSINESS / STRIPE_PRICE_NETWORK; оплата продлевает gyms.paid_until
  по уведомлению invoice.paid. Российские залы оплачивают подписку по счёту — дату ставит команда core. в /admin.
*/
export type CorePlan = "start" | "business" | "network";

export function billingKey(): string | null {
  return process.env.STRIPE_SECRET_KEY || null;
}

export function priceFor(plan: CorePlan): string | null {
  return process.env[`STRIPE_PRICE_${plan.toUpperCase()}`] || null;
}

export function billingAvailable(region: string | null | undefined, plan: CorePlan): boolean {
  return region === "AE" && !!billingKey() && !!priceFor(plan);
}

/** Дата окончания оплаченного периода (UTC) плюс 3 дня на списание следующего платежа */
export function paidUntilFromPeriodEnd(periodEnd: number): string {
  return new Date((periodEnd + 3 * 86400) * 1000).toISOString().slice(0, 10);
}
