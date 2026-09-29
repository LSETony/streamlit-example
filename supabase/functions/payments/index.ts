// Оплаты через ЮKassa (раздел 5.6, 8):
//   POST /v1/payments            — создать платёж: ссылка на оплату (кабинет) или токен для SDK/виджета (приложение)
//   GET  /v1/payments/{id}       — статус нашего платежа (приложение опрашивает после оплаты)
//   POST /v1/payments/refund     — возврат (владелец/администратор); онлайн — через ЮKassa
//   POST /v1/payments/webhook    — уведомления ЮKassa; статус перепроверяется запросом в ЮKassa,
//                                  обработка идемпотентна по provider_payment_id
import { ApiError, handler, json, optionalDate, pathParts, readJson, requireUuid } from "../_shared/http.ts";
import { adminClient, rpc, userClient } from "../_shared/supabase.ts";
import { createPayment, createRefund, getPayment, getRefund, gymShop } from "../_shared/yookassa.ts";
import { alertTeam } from "../_shared/alert.ts";

interface Purchase {
  payment_id: string;
  membership_id: string;
  gym_id: string;
  amount: number;
  description: string;
  client: { id: string; full_name: string; phone: string | null; email: string | null };
}

async function create(req: Request): Promise<Response> {
  const body = await readJson<{
    plan_id?: string; client_id?: string; starts_on?: string; renew_from?: string;
    mode?: "redirect" | "embedded"; payment_token?: string; return_url?: string;
  }>(req);
  const client = userClient(req);
  const purchase = await rpc<Purchase>(client, "start_online_purchase", {
    p_plan: requireUuid(body.plan_id, "plan_id"),
    p_client: body.client_id ? requireUuid(body.client_id, "client_id") : null,
    p_starts_on: optionalDate(body.starts_on, "starts_on"),
    p_renew_from: body.renew_from ? requireUuid(body.renew_from, "renew_from") : null,
  });

  try {
    const shop = await gymShop(purchase.gym_id);
    const returnUrl = body.return_url ?? `${Deno.env.get("PUBLIC_APP_URL") ?? ""}/pay/done?payment=${purchase.payment_id}`;
    const yk = await createPayment(shop, {
      paymentId: purchase.payment_id,
      gymId: purchase.gym_id,
      amount: purchase.amount,
      description: purchase.description,
      mode: body.mode ?? (body.client_id ? "redirect" : "embedded"),
      returnUrl,
      paymentToken: body.payment_token,
      customer: { phone: purchase.client.phone, email: purchase.client.email },
    });
    await rpc(adminClient(), "attach_provider_payment", {
      p_payment: purchase.payment_id,
      p_provider_payment_id: yk.id,
      p_confirmation_url: yk.confirmation?.confirmation_url ?? null,
    });
    // Платёж токеном из SDK может пройти сразу
    if (yk.status === "succeeded" || yk.status === "canceled") {
      await rpc(adminClient(), "confirm_online_payment", {
        p_provider: "yookassa", p_provider_payment_id: yk.id, p_status: yk.status, p_receipt_url: null,
      });
    }
    return json({
      payment_id: purchase.payment_id,
      membership_id: purchase.membership_id,
      amount: purchase.amount,
      status: yk.status,
      provider_payment_id: yk.id,
      confirmation_url: yk.confirmation?.confirmation_url ?? null,
      confirmation_token: yk.confirmation?.confirmation_token ?? null,
    }, 201);
  } catch (e) {
    // Платёж не создан у провайдера — снимаем «висящие» записи сразу, не дожидаясь ночного задания
    await adminClient().from("payments").update({ status: "failed" }).eq("id", purchase.payment_id).eq("status", "pending");
    await adminClient().from("memberships").update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", purchase.membership_id).eq("status", "pending");
    if (!(e instanceof ApiError) || e.code === "PAYMENT_PROVIDER_ERROR") {
      await alertTeam(`Не удалось создать платёж ЮKassa (зал ${purchase.gym_id}): ${e instanceof Error ? e.message : e}`);
    }
    throw e;
  }
}

async function status(req: Request, id: string): Promise<Response> {
  const { data, error } = await userClient(req)
    .from("payments")
    .select("id, status, amount, method, membership_id, paid_at, receipt_url, confirmation_url")
    .eq("id", requireUuid(id, "id"))
    .maybeSingle();
  if (error) throw new ApiError(500, "INTERNAL", "Не удалось получить платёж");
  if (!data) throw new ApiError(404, "PAYMENT_NOT_FOUND", "Платёж не найден");
  return json(data);
}

async function refund(req: Request): Promise<Response> {
  const body = await readJson<{ payment_id?: string; amount?: number; cancel_membership?: boolean; reason?: string }>(req);
  const paymentId = requireUuid(body.payment_id, "payment_id");
  if (body.amount !== undefined && (!Number.isInteger(body.amount) || body.amount <= 0)) {
    throw new ApiError(422, "INVALID_INPUT", "Сумма возврата — целое число копеек");
  }
  const client = userClient(req);
  const r = await rpc<{ refund_id: string; amount: number; status: string; needs_provider: boolean; provider_payment_id: string | null }>(
    client, "refund_payment", {
      p_payment: paymentId,
      p_amount: body.amount ?? null,
      p_cancel_membership: body.cancel_membership ?? false,
      p_reason: body.reason ?? null,
    });
  if (!r.needs_provider) return json(r);

  const { data: pay } = await adminClient().from("payments")
    .select("gym_id, client_id, clients(phone, email)").eq("id", paymentId).single();
  try {
    const shop = await gymShop(pay!.gym_id);
    const contact = (pay as unknown as { clients: { phone: string | null; email: string | null } | null }).clients;
    const yk = await createRefund(shop, r.refund_id, r.provider_payment_id!, r.amount, body.reason ?? "Возврат за абонемент",
      { phone: contact?.phone, email: contact?.email });
    await adminClient().from("payments").update({ provider_payment_id: yk.id }).eq("id", r.refund_id);
    if (yk.status !== "pending") {
      await rpc(adminClient(), "confirm_refund", { p_refund: r.refund_id, p_succeeded: yk.status === "succeeded", p_provider_refund_id: yk.id });
    }
    return json({ ...r, status: yk.status === "succeeded" ? "refunded" : yk.status === "canceled" ? "failed" : "pending" });
  } catch (e) {
    await rpc(adminClient(), "confirm_refund", { p_refund: r.refund_id, p_succeeded: false, p_provider_refund_id: null });
    await alertTeam(`Сбой возврата ${r.refund_id}: ${e instanceof Error ? e.message : e}`);
    throw e;
  }
}

async function webhook(req: Request): Promise<Response> {
  const body = await readJson<{ event?: string; object?: { id?: string; payment_id?: string } }>(req);
  const event = body.event ?? "";
  const objectId = body.object?.id;
  if (!objectId) return json({ result: "ignored" });
  const admin = adminClient();

  try {
    if (event.startsWith("payment.")) {
      const { data: pay } = await admin.from("payments").select("id, gym_id")
        .eq("provider", "yookassa").eq("provider_payment_id", objectId).is("refund_of_id", null).maybeSingle();
      if (!pay) return json({ result: "unknown_payment" });
      // Не доверяем телу уведомления: перепроверяем статус в ЮKassa ключами зала
      const shop = await gymShop(pay.gym_id);
      const yk = await getPayment(shop, objectId);
      const result = await rpc(admin, "confirm_online_payment", {
        p_provider: "yookassa", p_provider_payment_id: yk.id, p_status: yk.status, p_receipt_url: null,
      });
      return json(result);
    }
    if (event.startsWith("refund.")) {
      const { data: ref } = await admin.from("payments").select("id, gym_id")
        .eq("provider", "yookassa").eq("provider_payment_id", objectId).not("refund_of_id", "is", null).maybeSingle();
      if (!ref) return json({ result: "unknown_refund" });
      const shop = await gymShop(ref.gym_id);
      const yk = await getRefund(shop, objectId);
      if (yk.status === "pending") return json({ result: "pending" });
      return json(await rpc(admin, "confirm_refund", { p_refund: ref.id, p_succeeded: yk.status === "succeeded", p_provider_refund_id: yk.id }));
    }
    return json({ result: "ignored" });
  } catch (e) {
    await alertTeam(`Сбой обработки webhook ЮKassa (${event} ${objectId}): ${e instanceof Error ? e.message : e}`);
    throw e; // 5xx — ЮKassa повторит уведомление
  }
}

Deno.serve(handler((req) => {
  const [first] = pathParts(req, "payments");
  if (req.method === "POST" && !first) return create(req);
  if (req.method === "POST" && first === "webhook") return webhook(req);
  if (req.method === "POST" && first === "refund") return refund(req);
  if (req.method === "GET" && first) return status(req, first);
  throw new ApiError(404, "NOT_FOUND", "Метод не найден");
}));
