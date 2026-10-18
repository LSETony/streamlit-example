"use client";
import { useTransition } from "react";
import { CreditCard } from "lucide-react";
import { Button } from "@/components/ui/button";
import { manageSubscription, startSubscription } from "@/app/actions/billing";
import { toast } from "@/lib/toast";

/** Оплата подписки core. картой (Stripe Checkout) и управление ею (портал Stripe) */
export function BillingButtons({ subscribed }: { subscribed: boolean }) {
  const [pending, start] = useTransition();
  const go = (action: () => Promise<{ ok: true; data: string } | { ok: false; error: { message: string } }>) => start(async () => {
    const r = await action();
    if (!r.ok) return void toast.error(r.error.message);
    window.location.href = r.data;
  });
  return subscribed
    ? <Button variant="secondary" size="sm" disabled={pending} onClick={() => go(manageSubscription)}><CreditCard /> Управлять подпиской</Button>
    : <Button size="sm" disabled={pending} onClick={() => go(startSubscription)}><CreditCard /> Оплатить картой</Button>;
}
