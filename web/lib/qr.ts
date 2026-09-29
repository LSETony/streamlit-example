// Эталонная реализация динамического QR-пропуска (раздел 6) — так же его строит iOS-приложение.
// Формат: CORE1:<device_id>:<t>:<sig>, t = floor(unix/30),
// sig = первые 16 байт HMAC-SHA256(key = qr_secret (hex), msg = "CORE1:<device_id>:<t>") в hex.
export const QR_PERIOD_SECONDS = 30;

function hexToBytes(hex: string): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(new ArrayBuffer(hex.length / 2));
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export async function buildQrPayload(deviceId: string, secretHex: string, now: number = Date.now()): Promise<string> {
  const t = Math.floor(now / 1000 / QR_PERIOD_SECONDS);
  const msg = `CORE1:${deviceId}:${t}`;
  const key = await crypto.subtle.importKey("raw", hexToBytes(secretHex), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(msg)));
  return `${msg}:${bytesToHex(sig.slice(0, 16))}`;
}

/** Похоже ли содержимое на пропуск core. (быстрая проверка до запроса к серверу) */
export function looksLikeCoreQr(text: string): boolean {
  return /^CORE1:[0-9a-f-]{36}:\d{1,12}:[0-9a-f]{32}$/i.test(text.trim());
}
