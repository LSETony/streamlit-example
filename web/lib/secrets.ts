import "server-only";
import { createCipheriv, randomBytes } from "node:crypto";

// Шифрование ключа ЮKassa зала: AES-256-GCM, base64(iv[12] | ciphertext | tag[16]).
// Формат совместим с supabase/functions/_shared/crypto.ts (Web Crypto).
export function encryptSecret(plain: string): string {
  const raw = process.env.GYM_SECRETS_KEY;
  if (!raw) throw new Error("GYM_SECRETS_KEY не задан");
  const key = Buffer.from(raw, "base64");
  if (key.length !== 32) throw new Error("GYM_SECRETS_KEY должен быть 32 байта в base64");
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const enc = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  return Buffer.concat([iv, enc, cipher.getAuthTag()]).toString("base64");
}
