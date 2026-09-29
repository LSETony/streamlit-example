import { describe, expect, it } from "vitest";
import { addDays, daysBetween, money, parseRub, phone, plural, zonedToUtc } from "./format";

describe("format", () => {
  it("деньги в копейках", () => {
    expect(money(300000)).toBe("3 000 ₽");
    expect(money(150)).toBe("1,50 ₽");
    expect(parseRub("3 000")).toBe(300000);
    expect(parseRub("99,9")).toBe(9990);
    expect(parseRub("abc")).toBeNull();
  });
  it("склонения", () => {
    expect(plural(1, "визит", "визита", "визитов")).toBe("визит");
    expect(plural(3, "визит", "визита", "визитов")).toBe("визита");
    expect(plural(11, "визит", "визита", "визитов")).toBe("визитов");
    expect(plural(22, "визит", "визита", "визитов")).toBe("визита");
  });
  it("даты", () => {
    expect(addDays("2026-09-28", 30)).toBe("2026-10-28");
    expect(daysBetween("2026-09-28", "2026-10-28")).toBe(30);
    expect(zonedToUtc("2026-09-28", "19:00", "Europe/Moscow").toISOString()).toBe("2026-09-28T16:00:00.000Z");
    expect(zonedToUtc("2026-09-28", "19:00", "Asia/Yekaterinburg").toISOString()).toBe("2026-09-28T14:00:00.000Z");
  });
  it("телефон", () => {
    expect(phone("+79161234567")).toBe("+7 916 123-45-67");
  });
});
