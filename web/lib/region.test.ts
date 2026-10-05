import { describe, expect, it } from "vitest";
import { money, parseMoney, phone } from "./format";
import { normalizePhone } from "./phone";
import { regionInfo } from "./region";

describe("регионы", () => {
  it("деньги в валюте зала", () => {
    expect(money(300000).replace(/\s/g, " ")).toBe("3 000 ₽");
    expect(money(300000, "RUB").replace(/\s/g, " ")).toBe("3 000 ₽");
    expect(money(45000, "AED")).toBe("AED 450");
    expect(money(120050, "AED")).toBe("AED 1,200.50");
    expect(money(null, "AED")).toBe("—");
  });

  it("ввод суммы в обоих форматах", () => {
    expect(parseMoney("3 000")).toBe(300000);
    expect(parseMoney("3000,50")).toBe(300050);
    expect(parseMoney("1,200")).toBe(120000);
    expect(parseMoney("AED 1,200.50")).toBe(120050);
    expect(parseMoney("450 AED")).toBe(45000);
    expect(parseMoney("abc")).toBeNull();
  });

  it("телефоны ОАЭ приводятся к +971", () => {
    expect(normalizePhone("050 123 4567")).toBe("+971501234567");
    expect(normalizePhone("50 123 4567")).toBe("+971501234567");
    expect(normalizePhone("971501234567")).toBe("+971501234567");
    expect(normalizePhone("+971 50 123 4567")).toBe("+971501234567");
    expect(normalizePhone("8 916 123-45-67")).toBe("+79161234567");
    expect(phone("+971501234567")).toBe("+971 50 123 4567");
    expect(phone("+97143456789")).toBe("+971 4 345 6789");
    expect(phone("+79161234567")).toBe("+7 916 123-45-67");
  });

  it("настройки региона", () => {
    expect(regionInfo("AE")).toMatchObject({ currency: "AED", timezone: "Asia/Dubai", locale: "en", onlinePayments: false });
    expect(regionInfo("RU")).toMatchObject({ currency: "RUB", locale: "ru", onlinePayments: true });
    expect(regionInfo(undefined).currency).toBe("RUB");
  });
});
