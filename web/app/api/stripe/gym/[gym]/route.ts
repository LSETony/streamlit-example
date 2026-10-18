import { gymStripe } from "@/lib/stripe-gym";
import { verifyStripeSignature, type CheckoutSession } from "@/lib/stripe";
import { createAdminClient } from "@/lib/supabase/admin";

// Уведомления Stripe зала (ОАЭ): оплата абонемента по ссылке. Адрес для Stripe: /api/stripe/gym/<id зала>.
// Подпись проверяется секретом зала; активация идемпотентна по id сессии — повтор уведомления безопасен.
export async function POST(req: Request, { params }: RouteContext<"/api/stripe/gym/[gym]">) {
  const { gym } = await params;
  const payload = await req.text();
  const keys = /^[0-9a-f-]{36}$/i.test(gym) ? await gymStripe(gym) : null;
  if (!keys?.webhookSecret || !verifyStripeSignature(payload, req.headers.get("stripe-signature"), keys.webhookSecret)) {
    return Response.json({ error: "invalid signature" }, { status: 400 });
  }
  const event = JSON.parse(payload) as { type: string; data: { object: CheckoutSession } };
  const session = event.data.object;
  const status =
    event.type === "checkout.session.completed" && session.payment_status === "paid" ? "succeeded"
    : event.type === "checkout.session.async_payment_succeeded" ? "succeeded"
    : event.type === "checkout.session.expired" || event.type === "checkout.session.async_payment_failed" ? "canceled"
    : null;
  if (!status || session.mode !== "payment") return Response.json({ result: "ignored" });
  const admin = createAdminClient();
  const { data: pay } = await admin.from("payments").select("gym_id").eq("provider", "stripe").eq("provider_payment_id", session.id).maybeSingle();
  if (!pay || pay.gym_id !== gym) return Response.json({ result: "unknown_payment" });
  const { data, error } = await admin.rpc("confirm_online_payment", {
    p_provider: "stripe", p_provider_payment_id: session.id, p_status: status, p_receipt_url: null,
  });
  if (error) {
    console.error("stripe webhook", error);
    return Response.json({ error: "processing failed" }, { status: 500 }); // Stripe повторит уведомление
  }
  return Response.json(data);
}
