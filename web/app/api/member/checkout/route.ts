import { apiError, dbError, memberFromRequest } from "@/lib/member-api";
import { appOrigin } from "@/lib/origin";
import { regionInfo } from "@/lib/region";
import { createAdminClient } from "@/lib/supabase/admin";
import { serverUrl } from "@/lib/supabase/config";
import { createGymCheckout, gymStripe, type Purchase } from "@/lib/stripe-gym";

// POST /api/member/checkout {plan_id} — покупка абонемента из приложения клиента.
// Возвращает {url}: страницу оплаты Stripe (залы в ОАЭ) или ЮKassa (Россия). Абонемент активируется
// по уведомлению платёжного сервиса, приложение затем просто обновляет список абонементов.
export async function POST(req: Request) {
  const member = await memberFromRequest(req);
  if (!member) return apiError(401, "UNAUTHORIZED", "Требуется вход");
  const body = await req.json().catch(() => ({})) as { plan_id?: string };
  if (!body.plan_id || !/^[0-9a-f-]{36}$/i.test(body.plan_id)) return apiError(422, "INVALID_INPUT", "Укажите тариф");

  const { data: plan } = await member.db.from("membership_plans").select("gym_id").eq("id", body.plan_id).maybeSingle();
  if (!plan) return apiError(404, "PLAN_NOT_FOUND", "Тариф не найден");
  const { data: gym } = await member.db.rpc("public_gym", { p_gym: plan.gym_id });
  const region = regionInfo((gym as { region?: string } | null)?.region);
  const origin = await appOrigin();

  if (region.paymentProvider === "yookassa") {
    // Россия: платёж создаёт Edge Function payments (ЮKassa), как и для веб-приложения
    const res = await fetch(`${serverUrl()}/functions/v1/payments`, {
      method: "POST",
      headers: { Authorization: `Bearer ${member.token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ plan_id: body.plan_id, mode: "redirect", return_url: `${origin}/pay/done` }),
    });
    const data = await res.json().catch(() => ({})) as { confirmation_url?: string; code?: string; message?: string };
    if (!res.ok || !data.confirmation_url) return apiError(res.ok ? 502 : res.status, data.code ?? "PAYMENT_PROVIDER_ERROR", data.message ?? "Онлайн-оплата недоступна");
    return Response.json({ url: data.confirmation_url });
  }

  const keys = await gymStripe(plan.gym_id);
  if (!keys) return apiError(422, "STRIPE_NOT_CONNECTED", "Зал пока не принимает онлайн-оплату");
  const { data: purchase, error } = await member.db.rpc("start_online_purchase", { p_plan: body.plan_id, p_client: null });
  if (error) return dbError(error);
  const p = purchase as Purchase;
  const admin = createAdminClient();
  try {
    await admin.from("payments").update({ provider: "stripe" }).eq("id", p.payment_id);
    const session = await createGymCheckout(keys.secret, p, region.currency, origin);
    await admin.rpc("attach_provider_payment", { p_payment: p.payment_id, p_provider_payment_id: session.id, p_confirmation_url: session.url });
    return Response.json({ url: session.url, payment_id: p.payment_id });
  } catch (e) {
    await admin.from("payments").update({ status: "failed" }).eq("id", p.payment_id).eq("status", "pending");
    await admin.from("memberships").update({ status: "cancelled", cancelled_at: new Date().toISOString() }).eq("id", p.membership_id).eq("status", "pending");
    console.error("member checkout failed", e);
    return apiError(502, "PAYMENT_PROVIDER_ERROR", "Не удалось создать платёж. Попробуйте позже");
  }
}
