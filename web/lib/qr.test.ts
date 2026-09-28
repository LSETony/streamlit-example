import { createHmac } from "node:crypto";
import { describe, expect, it } from "vitest";
import { buildQrPayload, looksLikeCoreQr } from "./qr";

describe("динамический QR", () => {
  const device = "00000000-0000-0000-0000-00000000d001";
  const secret = "ab".repeat(32);

  it("совпадает с эталонным HMAC (как в функции БД verify_qr)", async () => {
    const now = 1_790_000_000_000;
    const payload = await buildQrPayload(device, secret, now);
    const t = Math.floor(now / 1000 / 30);
    const msg = `CORE1:${device}:${t}`;
    const sig = createHmac("sha256", Buffer.from(secret, "hex")).update(msg).digest("hex").slice(0, 32);
    expect(payload).toBe(`${msg}:${sig}`);
    expect(looksLikeCoreQr(payload)).toBe(true);
  });

  it("меняется каждые 30 секунд", async () => {
    const a = await buildQrPayload(device, secret, 1_790_000_000_000);
    const b = await buildQrPayload(device, secret, 1_790_000_030_000);
    expect(a).not.toBe(b);
  });

  it("отбрасывает посторонние коды", () => {
    expect(looksLikeCoreQr("https://example.com")).toBe(false);
  });
});
