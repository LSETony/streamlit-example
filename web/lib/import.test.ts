import { describe, expect, it } from "vitest";
import { chunk, guessMapping, parseDate, prepareRows } from "./import";
import { normalizePhone } from "./phone";

describe("normalizePhone", () => {
  it("приводит российские номера к +7", () => {
    expect(normalizePhone("8 (916) 123-45-67")).toBe("+79161234567");
    expect(normalizePhone("9161234567")).toBe("+79161234567");
    expect(normalizePhone("+7 916 123 45 67")).toBe("+79161234567");
    expect(normalizePhone("79161234567")).toBe("+79161234567");
    expect(normalizePhone("12345")).toBeNull();
    expect(normalizePhone("")).toBeNull();
  });
});

describe("parseDate", () => {
  it("понимает форматы из Excel", () => {
    expect(parseDate("31.12.2026")).toBe("2026-12-31");
    expect(parseDate("01.02.92")).toBe("1992-02-01");
    expect(parseDate("2026-09-01")).toBe("2026-09-01");
    expect(parseDate(46022)).toBe("2025-12-31");
    expect(parseDate(new Date(Date.UTC(2026, 8, 28)))).toBe("2026-09-28");
    expect(parseDate("31.02.2026")).toBe("invalid");
    expect(parseDate("")).toBeNull();
  });
});

describe("guessMapping", () => {
  it("находит колонки по заголовкам", () => {
    const m = guessMapping(["№", "ФИО", "Моб. телефон", "Дата рождения", "Абонемент", "Действует до", "Осталось занятий"]);
    expect(m.full_name).toBe(1);
    expect(m.phone).toBe(2);
    expect(m.birth_date).toBe(3);
    expect(m.plan_name).toBe(4);
    expect(m.ends_on).toBe(5);
    expect(m.visits_left).toBe(6);
  });
  it("фамилия и имя отдельными колонками", () => {
    const m = guessMapping(["Фамилия", "Имя", "Телефон"]);
    expect(m.last_name).toBe(0);
    expect(m.first_name).toBe(1);
    expect(m.phone).toBe(2);
  });
});

describe("prepareRows", () => {
  it("строки с ошибками отсекаются с номером строки и причиной, остальные проходят", () => {
    const data = [
      ["ФИО", "Телефон", "Окончание"],
      ["Иван Петров", "89161234567", "30.10.2026"],
      ["", "89161234568", ""],
      ["Мария", "123", ""],
      ["Олег", 9161234569, "32.10.2026"],
      [null, null, null],
    ];
    const { rows, issues } = prepareRows(data, { full_name: 0, phone: 1, ends_on: 2 });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ row: 2, full_name: "Иван Петров", phone: "+79161234567", ends_on: "2026-10-30" });
    expect(issues.map((i) => i.row)).toEqual([3, 4, 5]);
  });
  it("1000 строк готовятся мгновенно и режутся на пачки", () => {
    const data = [["ФИО", "Телефон"], ...Array.from({ length: 1000 }, (_, i) => [`Клиент ${i}`, `+7916${String(i).padStart(7, "0")}`])];
    const t = performance.now();
    const { rows } = prepareRows(data, { full_name: 0, phone: 1 });
    expect(performance.now() - t).toBeLessThan(500);
    expect(chunk(rows, 500)).toHaveLength(2);
  });
});
