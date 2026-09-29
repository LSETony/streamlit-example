// Шифрование ключей ЮKassa зала: AES-256-GCM, формат base64(iv[12] | ciphertext | tag[16]).
// Ключ — переменная окружения GYM_SECRETS_KEY (base64, 32 байта). Совместимо с web/lib/secrets.ts.
function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToB64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

function key(): Promise<CryptoKey> {
  const raw = Deno.env.get("GYM_SECRETS_KEY");
  if (!raw) throw new Error("GYM_SECRETS_KEY не задан");
  return crypto.subtle.importKey("raw", b64ToBytes(raw), "AES-GCM", false, ["encrypt", "decrypt"]);
}

export async function decryptSecret(payload: string): Promise<string> {
  const data = b64ToBytes(payload);
  const iv = data.slice(0, 12);
  const body = data.slice(12);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, await key(), body);
  return new TextDecoder().decode(plain);
}

export async function encryptSecret(plain: string): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const enc = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv }, await key(), new TextEncoder().encode(plain)));
  const out = new Uint8Array(iv.length + enc.length);
  out.set(iv);
  out.set(enc, iv.length);
  return bytesToB64(out);
}
