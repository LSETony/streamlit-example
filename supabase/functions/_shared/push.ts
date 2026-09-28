// Отправка уведомлений: push через APNs (iOS-приложение core.), SMS через российский шлюз, email.
// Конфигурация — переменные окружения; если канал не настроен, отправка помечается как пропущенная.

let apnsJwt: { token: string; at: number } | null = null;

function b64url(bytes: Uint8Array | string): string {
  const b = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  for (const x of b) s += String.fromCharCode(x);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function apnsToken(): Promise<string> {
  // JWT живёт до часа; обновляем раз в 50 минут
  if (apnsJwt && Date.now() - apnsJwt.at < 50 * 60 * 1000) return apnsJwt.token;
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const pem = Deno.env.get("APNS_PRIVATE_KEY")!.replace(/\\n/g, "\n");
  const der = Uint8Array.from(atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "")), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const header = b64url(JSON.stringify({ alg: "ES256", kid: keyId }));
  const claims = b64url(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key,
    new TextEncoder().encode(`${header}.${claims}`)));
  const token = `${header}.${claims}.${b64url(sig)}`;
  apnsJwt = { token, at: Date.now() };
  return token;
}

export function pushConfigured(): boolean {
  return Boolean(Deno.env.get("APNS_KEY_ID") && Deno.env.get("APNS_TEAM_ID") && Deno.env.get("APNS_PRIVATE_KEY") &&
    Deno.env.get("APNS_BUNDLE_ID"));
}

export type SendResult = { ok: true } | { ok: false; error: string; permanent?: boolean };

export async function sendPush(deviceToken: string, title: string, body: string, data: Record<string, unknown>): Promise<SendResult> {
  const host = Deno.env.get("APNS_PRODUCTION") === "true" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${await apnsToken()}`,
      "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" }, ...data }),
  });
  if (res.ok) return { ok: true };
  const text = await res.text();
  // 410 / BadDeviceToken — токен больше не действителен
  return { ok: false, error: `APNs ${res.status}: ${text}`, permanent: res.status === 410 || text.includes("BadDeviceToken") };
}

export function smsConfigured(): boolean {
  return Boolean(Deno.env.get("SMSRU_API_ID"));
}

export async function sendSms(phone: string, text: string): Promise<SendResult> {
  const url = new URL("https://sms.ru/sms/send");
  url.searchParams.set("api_id", Deno.env.get("SMSRU_API_ID")!);
  url.searchParams.set("to", phone.replace(/\D/g, ""));
  url.searchParams.set("msg", text);
  url.searchParams.set("json", "1");
  const sender = Deno.env.get("SMSRU_FROM");
  if (sender) url.searchParams.set("from", sender);
  const res = await fetch(url);
  const data = await res.json().catch(() => ({}));
  if (res.ok && data.status === "OK") return { ok: true };
  return { ok: false, error: `SMS.ru: ${JSON.stringify(data).slice(0, 300)}` };
}

export function emailConfigured(): boolean {
  return Boolean(Deno.env.get("UNISENDER_GO_API_KEY") && Deno.env.get("EMAIL_FROM"));
}

export async function sendEmail(to: string, subject: string, text: string, fromName: string): Promise<SendResult> {
  const res = await fetch("https://go1.unisender.ru/ru/transactional/api/v1/email/send.json", {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-API-KEY": Deno.env.get("UNISENDER_GO_API_KEY")! },
    body: JSON.stringify({
      message: {
        recipients: [{ email: to }],
        subject,
        from_email: Deno.env.get("EMAIL_FROM"),
        from_name: fromName,
        body: { plaintext: text },
      },
    }),
  });
  if (res.ok) return { ok: true };
  return { ok: false, error: `email ${res.status}: ${(await res.text()).slice(0, 300)}` };
}
