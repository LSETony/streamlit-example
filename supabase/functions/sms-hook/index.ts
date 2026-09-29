// Send SMS Hook для Supabase Auth: коды входа в приложение отправляются через российский шлюз (SMS.ru),
// а не через Twilio. Подпись запроса проверяется по стандарту Standard Webhooks (секрет SEND_SMS_HOOK_SECRET).
import { ApiError, handler, json } from "../_shared/http.ts";
import { sendSms, smsConfigured } from "../_shared/push.ts";
import { alertTeam } from "../_shared/alert.ts";

function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function verify(req: Request, body: string): Promise<boolean> {
  const secret = Deno.env.get("SEND_SMS_HOOK_SECRET")?.replace(/^v1,whsec_/, "");
  const id = req.headers.get("webhook-id");
  const ts = req.headers.get("webhook-timestamp");
  const sigs = req.headers.get("webhook-signature");
  if (!secret || !id || !ts || !sigs) return false;
  if (Math.abs(Date.now() / 1000 - Number(ts)) > 300) return false;
  const key = await crypto.subtle.importKey("raw", b64ToBytes(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${ts}.${body}`)));
  let expected = "";
  for (const b of mac) expected += String.fromCharCode(b);
  expected = btoa(expected);
  return sigs.split(" ").some((s) => s.split(",")[1] === expected);
}

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте POST");
  const body = await req.text();
  if (!(await verify(req, body))) throw new ApiError(401, "UNAUTHORIZED", "Неверная подпись");
  const payload = JSON.parse(body) as { user: { phone: string }; sms: { otp: string } };
  if (!smsConfigured()) throw new ApiError(503, "SMS_NOT_CONFIGURED", "SMS-шлюз не настроен");
  const r = await sendSms(payload.user.phone, `Код для входа в core.: ${payload.sms.otp}`);
  if (!r.ok) {
    await alertTeam(`Не отправлен SMS-код входа: ${r.error}`);
    throw new ApiError(502, "SMS_FAILED", "Не удалось отправить SMS");
  }
  return json({});
}));
