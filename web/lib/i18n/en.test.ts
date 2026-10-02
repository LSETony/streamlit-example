import { describe, expect, it } from "vitest";
import ts from "typescript";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { EN, EN_PATTERNS } from "./en";
import { makeT, localeFromAcceptLanguage } from "./core";

// Русские строки, которые не показываются в интерфейсе как есть: синонимы заголовков импорта,
// тексты согласий для БД, сообщения для разработчика, примеры в шаблоне импорта
const SKIP_FILES = [/\.test\.tsx?$/, /lib\/i18n\//, /lib\/secrets\.ts$/, /lib\/supabase\//];
const SKIP = new Set([
  "Согласие на обработку персональных данных получено залом (отметка в кабинете core.)",
  "Согласие на получение рассылок получено залом (отметка в кабинете core.)",
  "Иванова Мария Сергеевна", "утро, пилатес", "Цель — спина", "ж", "е",
]);

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    return statSync(p).isDirectory() ? files(p) : /\.tsx?$/.test(f) ? [p] : [];
  });
}

/** Все русские строковые литералы и JSX-тексты интерфейса */
function russianStrings(): Map<string, string> {
  const out = new Map<string, string>();
  const cyr = /[А-Яа-яЁё]/;
  for (const f of ["app", "components", "lib"].flatMap(files)) {
    if (SKIP_FILES.some((r) => r.test(f))) continue;
    const src = ts.createSourceFile(f, readFileSync(f, "utf8"), ts.ScriptTarget.Latest, true, f.endsWith("x") ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
    // синонимы колонок импорта — для распознавания заголовков, не для показа
    const isSynonyms = (n: ts.Node) => ts.isPropertyAssignment(n.parent?.parent) && n.parent.parent.name.getText() === "synonyms";
    const visit = (n: ts.Node) => {
      if ((ts.isStringLiteral(n) || ts.isNoSubstitutionTemplateLiteral(n)) && cyr.test(n.text) && !isSynonyms(n)) out.set(n.text, f);
      else if (ts.isJsxText(n) && cyr.test(n.text)) out.set(n.text.replace(/\s+/g, " ").trim(), f);
      ts.forEachChild(n, visit);
    };
    visit(src);
  }
  return out;
}

describe("i18n", () => {
  it("у каждой строки интерфейса есть английский перевод", () => {
    const strings = russianStrings();
    expect(strings.size).toBeGreaterThan(500);
    const missing = [...strings].filter(([s]) => !SKIP.has(s) && !(s in EN) && !EN_PATTERNS.some(([re]) => re.test(s)));
    expect(missing.map(([s, f]) => `${f}: ${s}`)).toEqual([]);
  });

  it("подстановки и формы слова совпадают", () => {
    for (const [ru, en] of Object.entries(EN)) {
      const vars = (s: string) => (s.match(/\{\w+\}/g) ?? []).sort().join();
      expect(vars(en), ru).toBe(vars(ru));
      if (ru.includes("|")) expect(en.split("|").length, ru).toBe(2);
      expect(/[А-Яа-яЁё]/.test(en), `${ru} → ${en}`).toBe(false);
    }
  });

  it("переводит, склоняет и разбирает сообщения", () => {
    const en = makeT("en");
    const ru = makeT("ru");
    expect(en("Клиенты")).toBe("Clients");
    expect(ru("Клиенты")).toBe("Клиенты");
    expect(en("Показано {n} из {total}", { n: 5, total: 9 })).toBe("Showing 5 of 9");
    expect(en.n(1, "клиент|клиента|клиентов")).toBe("client");
    expect(en.n(3, "клиент|клиента|клиентов")).toBe("clients");
    expect(ru.n(3, "клиент|клиента|клиентов")).toBe("клиента");
    expect(ru.n(11, "клиент|клиента|клиентов")).toBe("клиентов");
    expect(en("Клиент с этим телефоном уже есть: Анна")).toBe("A client with this phone already exists: Анна");
    expect(en("Превышен лимит заморозки: доступно 5 дн.")).toBe("Freeze limit exceeded: 5 days available");
    expect(en("Незнакомая строка")).toBe("Незнакомая строка");
  });

  it("язык по браузеру", () => {
    expect(localeFromAcceptLanguage("en-US,en;q=0.9")).toBe("en");
    expect(localeFromAcceptLanguage("ru-RU,ru;q=0.9,en;q=0.8")).toBe("ru");
    expect(localeFromAcceptLanguage("de-DE,ru;q=0.5")).toBe("ru");
    expect(localeFromAcceptLanguage("de-DE")).toBe("en");
    expect(localeFromAcceptLanguage(null)).toBe("ru");
  });
});
