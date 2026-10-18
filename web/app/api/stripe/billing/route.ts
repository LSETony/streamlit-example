import { verifyStripeSignature, type CheckoutSession } from "@/lib/stripe";
import { paidUntilFromPeriodEnd } from "@/lib/billing";
import { createAdminClient } from "@/lib/supabase/admin";

// Уведомления Stripe-аккаунта core.: подписка зала на core. Подпись — STRIPE_WEBHOOK_SECRET.
// invoice.paid продлевает gyms.paid_until до конца оплаченного периода; дата только увеличивается.
interface Invoice {
  customer: string | null;
  subscription?: string | null;
  lines?: { data?: { period?: { end?: number } }[] };
  subscription_details?: { metadata?: Record<string, string> | null } | null;
  parent?: { subscription_details?: { subscription?: string; metadata?: Record<string, string> | null } | null } | null;
}

export async function POST(req: Request) {
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  const payload = await req.text();
  if (!secret || !verifyStripeSignature(payload, req.headers.get("stripe-signature"), secret)) {
    return Response.json({ error: "invalid signature" }, { status: 400 });
  }
  const event = JSON.parse(payload) as { type: string; data: { object: unknown } };
  const admin = createAdminClient();

  if (event.type === "checkout.session.completed") {
    const s = event.data.object as CheckoutSession;
    const gymId = s.metadata?.gym_id ?? s.client_reference_id;
    if (s.mode !== "subscription" || !gymId) return Response.json({ result: "ignored" });
    await admin.from("gyms").update({ stripe_customer_id: s.customer, stripe_subscription_id: s.subscription }).eq("id", gymId);
    return Response.json({ result: "linked" });
  }

  if (event.type === "invoice.paid") {
    const inv = event.data.object as Invoice;
    const meta = inv.parent?.subscription_details?.metadata ?? inv.subscription_details?.metadata ?? null;
    let gymId = meta?.gym_id ?? null;
    if (!gymId && inv.customer) {
      const { data } = await admin.from("gyms").select("id").eq("stripe_customer_id", inv.customer).maybeSingle();
      gymId = data?.id ?? null;
    }
    const end = Math.max(0, ...(inv.lines?.data ?? []).map((l) => l.period?.end ?? 0));
    if (!gymId || !end) return Response.json({ result: "ignored" });
    const until = paidUntilFromPeriodEnd(end);
    const { data: gym } = await admin.from("gyms").select("paid_until").eq("id", gymId).maybeSingle();
    if (!gym) return Response.json({ result: "unknown_gym" });
    const patch: Record<string, unknown> = { stripe_customer_id: inv.customer };
    if (!gym.paid_until || gym.paid_until < until) patch.paid_until = until;
    const { error } = await admin.from("gyms").update(patch).eq("id", gymId);
    if (error) return Response.json({ error: "processing failed" }, { status: 500 });
    return Response.json({ result: "paid", paid_until: patch.paid_until ?? gym.paid_until });
  }

  if (event.type === "customer.subscription.deleted") {
    const sub = event.data.object as { id: string };
    await admin.from("gyms").update({ stripe_subscription_id: null }).eq("stripe_subscription_id", sub.id);
    return Response.json({ result: "cancelled" });
  }
  return Response.json({ result: "ignored" });
}
