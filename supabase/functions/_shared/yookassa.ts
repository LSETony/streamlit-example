// Интеграция с ЮKassa (раздел 8). Каждый зал подключает свой магазин — деньги идут прямо залу.
// Все запросы идемпотентны (заголовок Idempotence-Key = наш id платежа/возврата).
import { adminClient } from "./supabase.ts";
import { decryptSecret } from "./crypto.ts";
import { ApiError } from "./http.ts";

// YOOKASSA_API_URL — только для тестов с имитацией ЮKassa
const API = Deno.env.get("YOOKASSA_API_URL") ?? "https://api.yookassa.ru/v3";

export interface GymShop {
  shopId: string;
  secretKey: string;
  sendReceipt: boolean;
  vatCode: number;
}

export async function gymShop(gymId: string): Promise<GymShop> {
  const { data, error } = await adminClient()
    .from("gym_secrets")
    .select("yookassa_shop_id, yookassa_secret_encrypted, yookassa_send_receipt, vat_code")
    .eq("gym_id", gymId)
    .maybeSingle();
  if (error) throw error;
  if (!data?.yookassa_shop_id || !data.yookassa_secret_encrypted) {
    throw new ApiError(422, "ONLINE_PAYMENTS_NOT_CONFIGURED", "Зал ещё не подключил онлайн-оплату");
  }
  return {
    shopId: data.yookassa_shop_id,
    secretKey: await decryptSecret(data.yookassa_secret_encrypted),
    sendReceipt: data.yookassa_send_receipt,
    vatCode: data.vat_code,
  };
}

export function rub(kopecks: number): string {
  return (kopecks / 100).toFixed(2);
}

async function call<T>(shop: GymShop, method: string, path: string, body?: unknown, idempotenceKey?: string): Promise<T> {
  const headers: Record<string, string> = {
    "Authorization": "Basic " + btoa(`${shop.shopId}:${shop.secretKey}`),
    "Content-Type": "application/json",
  };
  if (idempotenceKey) headers["Idempotence-Key"] = idempotenceKey;
  const res = await fetch(API + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  const data = text ? JSON.parse(text) : {};
  if (!res.ok) {
    console.error("yookassa error", res.status, data);
    throw new ApiError(502, "PAYMENT_PROVIDER_ERROR",
      data?.description ? `ЮKassa: ${data.description}` : "Платёжная система недоступна, попробуйте позже");
  }
  return data as T;
}

export interface YkPayment {
  id: string;
  status: "pending" | "waiting_for_capture" | "succeeded" | "canceled";
  amount: { value: string; currency: string };
  confirmation?: { type: string; confirmation_url?: string; confirmation_token?: string };
  metadata?: Record<string, string>;
  receipt_registration?: string;
}

export interface CreatePaymentInput {
  paymentId: string;          // наш payments.id — ключ идемпотентности и metadata
  gymId: string;
  amount: number;             // копейки
  description: string;
  mode: "redirect" | "embedded";
  returnUrl?: string;
  paymentToken?: string;      // токен из мобильного SDK ЮKassa
  customer: { phone?: string | null; email?: string | null };
}

export function createPayment(shop: GymShop, input: CreatePaymentInput): Promise<YkPayment> {
  const body: Record<string, unknown> = {
    amount: { value: rub(input.amount), currency: "RUB" },
    capture: true,
    description: input.description.slice(0, 128),
    metadata: { payment_id: input.paymentId, gym_id: input.gymId },
  };
  if (input.paymentToken) {
    body.payment_token = input.paymentToken;
    if (input.returnUrl) body.confirmation = { type: "redirect", return_url: input.returnUrl };
  } else if (input.mode === "embedded") {
    body.confirmation = { type: "embedded" };
  } else {
    body.confirmation = { type: "redirect", return_url: input.returnUrl };
  }
  // Чек по 54-ФЗ
  if (shop.sendReceipt && (input.customer.phone || input.customer.email)) {
    body.receipt = {
      customer: input.customer.email ? { email: input.customer.email } : { phone: input.customer.phone?.replace("+", "") },
      items: [{
        description: input.description.slice(0, 128),
        quantity: "1.00",
        amount: { value: rub(input.amount), currency: "RUB" },
        vat_code: shop.vatCode,
        payment_mode: "full_payment",
        payment_subject: "service",
      }],
    };
  }
  return call<YkPayment>(shop, "POST", "/payments", body, input.paymentId);
}

export function getPayment(shop: GymShop, id: string): Promise<YkPayment> {
  return call<YkPayment>(shop, "GET", `/payments/${encodeURIComponent(id)}`);
}

export interface YkRefund {
  id: string;
  payment_id: string;
  status: "pending" | "succeeded" | "canceled";
}

export function createRefund(shop: GymShop, refundId: string, providerPaymentId: string, amount: number, description: string,
                             customer: { phone?: string | null; email?: string | null }): Promise<YkRefund> {
  const body: Record<string, unknown> = {
    payment_id: providerPaymentId,
    amount: { value: rub(amount), currency: "RUB" },
    description: description.slice(0, 250),
  };
  if (shop.sendReceipt && (customer.phone || customer.email)) {
    body.receipt = {
      customer: customer.email ? { email: customer.email } : { phone: customer.phone?.replace("+", "") },
      items: [{
        description: description.slice(0, 128),
        quantity: "1.00",
        amount: { value: rub(amount), currency: "RUB" },
        vat_code: shop.vatCode,
        payment_mode: "full_payment",
        payment_subject: "service",
      }],
    };
  }
  return call<YkRefund>(shop, "POST", "/refunds", body, refundId);
}

export function getRefund(shop: GymShop, id: string): Promise<YkRefund> {
  return call<YkRefund>(shop, "GET", `/refunds/${encodeURIComponent(id)}`);
}
