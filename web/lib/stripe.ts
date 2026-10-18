import { createHmac, timingSafeEqual } from "node:crypto";

/*
  Минимальный клиент Stripe API без SDK: запросы form-urlencoded и проверка подписи уведомлений (webhook).
  STRIPE_API_BASE позволяет подменить адрес API в тестах.
*/

type Params = Record<string, unknown>;

export class StripeError extends Error {
  constructor(message: string, public status: number, public code?: string) {
    super(message);
  }
}

/** { line_items: [{ price: "p" }] } → line_items[0][price]=p — вложенный формат Stripe */
export function encodeParams(params: Params, prefix = "", out = new URLSearchParams()): URLSearchParams {
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null) continue;
    const key = prefix ? `${prefix}[${k}]` : k;
    if (Array.isArray(v)) v.forEach((item, i) => {
      if (item !== null && typeof item === "object") encodeParams(item as Params, `${key}[${i}]`, out);
      else out.append(`${key}[${i}]`, String(item));
    });
    else if (typeof v === "object") encodeParams(v as Params, key, out);
    else out.append(key, String(v));
  }
  return out;
}

export async function stripeRequest<T>(secretKey: string, method: "GET" | "POST", path: string, params: Params = {}): Promise<T> {
  const base = process.env.STRIPE_API_BASE ?? "https://api.stripe.com";
  const body = encodeParams(params).toString();
  const url = method === "GET" && body ? `${base}${path}?${body}` : `${base}${path}`;
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${secretKey}`, "Content-Type": "application/x-www-form-urlencoded" },
    body: method === "POST" ? body : undefined,
    cache: "no-store",
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = (data as { error?: { message?: string; code?: string } }).error;
    throw new StripeError(err?.message ?? `Stripe HTTP ${res.status}`, res.status, err?.code);
  }
  return data as T;
}

/** Проверка заголовка Stripe-Signature: t=…,v1=… — HMAC-SHA256 от "t.payload", не старше tolerance секунд */
export function verifyStripeSignature(payload: string, header: string | null, secret: string, toleranceSec = 300, now = Date.now()): boolean {
  if (!header) return false;
  const parts = header.split(",").map((p) => p.split("=") as [string, string]);
  const t = parts.find(([k]) => k === "t")?.[1];
  const sigs = parts.filter(([k]) => k === "v1").map(([, v]) => v);
  if (!t || !sigs.length || !/^\d+$/.test(t)) return false;
  if (Math.abs(now / 1000 - Number(t)) > toleranceSec) return false;
  const expected = createHmac("sha256", secret).update(`${t}.${payload}`).digest();
  return sigs.some((s) => {
    const got = Buffer.from(s, "hex");
    return got.length === expected.length && timingSafeEqual(got, expected);
  });
}

/** Подпись для тестов и локальной проверки уведомлений */
export function signStripePayload(payload: string, secret: string, t = Math.floor(Date.now() / 1000)): string {
  return `t=${t},v1=${createHmac("sha256", secret).update(`${t}.${payload}`).digest("hex")}`;
}

export interface CheckoutSession {
  id: string; url: string | null; mode: string; status: string; payment_status: string;
  payment_intent: string | null; customer: string | null; subscription: string | null;
  client_reference_id: string | null; metadata: Record<string, string> | null;
}
