import { describe, expect, it } from "vitest";
import { encodeParams, signStripePayload, verifyStripeSignature } from "./stripe";

describe("stripe", () => {
  it("кодирует вложенные параметры как Stripe", () => {
    const q = encodeParams({ mode: "payment", line_items: [{ quantity: 1, price_data: { currency: "aed", unit_amount: 45000 } }], metadata: { payment_id: "p1" }, skip: null });
    expect(decodeURIComponent(q.toString())).toBe(
      "mode=payment&line_items[0][quantity]=1&line_items[0][price_data][currency]=aed&line_items[0][price_data][unit_amount]=45000&metadata[payment_id]=p1");
  });

  it("проверяет подпись уведомления", () => {
    const body = JSON.stringify({ id: "evt_1" });
    const header = signStripePayload(body, "whsec_test");
    expect(verifyStripeSignature(body, header, "whsec_test")).toBe(true);
    expect(verifyStripeSignature(body + " ", header, "whsec_test")).toBe(false);
    expect(verifyStripeSignature(body, header, "whsec_other")).toBe(false);
    expect(verifyStripeSignature(body, null, "whsec_test")).toBe(false);
    const old = signStripePayload(body, "whsec_test", Math.floor(Date.now() / 1000) - 3600);
    expect(verifyStripeSignature(body, old, "whsec_test")).toBe(false);
  });
});
