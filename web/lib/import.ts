// Импорт клиентов из Excel/CSV (FR-2.4): распознавание колонок, разбор дат и телефонов, подготовка строк.
import { normalizePhone } from "./phone";

export type FieldKey =
  | "full_name" | "last_name" | "first_name" | "middle_name" | "phone" | "email" | "birth_date" | "gender"
  | "source" | "tags" | "note" | "plan_name" | "starts_on" | "ends_on" | "visits_left";

export const FIELDS: { key: FieldKey; label: string; synonyms: string[] }[] = [
  { key: "full_name", label: "ФИО", synonyms: ["фио", "ф.и.о", "клиент", "имя клиента", "full name", "name", "фамилия имя"] },
  { key: "last_name", label: "Фамилия", synonyms: ["фамилия", "last name", "surname"] },
  { key: "first_name", label: "Имя", synonyms: ["имя", "first name"] },
  { key: "middle_name", label: "Отчество", synonyms: ["отчество", "middle name"] },
  { key: "phone", label: "Телефон", synonyms: ["телефон", "тел", "моб", "мобильный", "phone", "номер телефона", "номер"] },
  { key: "email", label: "Email", synonyms: ["email", "e-mail", "почта", "эл. почта", "электронная почта"] },
  { key: "birth_date", label: "Дата рождения", synonyms: ["дата рождения", "день рождения", "др", "birthday", "birth date"] },
  { key: "gender", label: "Пол", synonyms: ["пол", "gender", "sex"] },
  { key: "source", label: "Источник", synonyms: ["источник", "откуда", "канал", "source"] },
  { key: "tags", label: "Теги", synonyms: ["теги", "метки", "tags", "группа"] },
  { key: "note", label: "Заметка", synonyms: ["заметка", "комментарий", "примечание", "note", "comment"] },
  { key: "plan_name", label: "Абонемент (тариф)", synonyms: ["абонемент", "тариф", "вид абонемента", "plan"] },
  { key: "starts_on", label: "Начало абонемента", synonyms: ["начало", "дата начала", "с", "начало абонемента", "дата покупки", "start"] },
  { key: "ends_on", label: "Окончание абонемента", synonyms: ["окончание", "дата окончания", "действует до", "до", "конец", "окончание абонемента", "end"] },
  { key: "visits_left", label: "Осталось визитов", synonyms: ["осталось визитов", "остаток", "визитов осталось", "осталось занятий", "остаток занятий"] },
];

export type Mapping = Partial<Record<FieldKey, number>>;
export type CellValue = string | number | boolean | Date | null | undefined;

const norm = (s: string) => s.toLowerCase().replace(/ё/g, "е").replace(/[^a-zа-я0-9. -]/g, "").replace(/\s+/g, " ").trim();

/** Автоматическое сопоставление колонок по заголовкам */
export function guessMapping(headers: string[]): Mapping {
  const mapping: Mapping = {};
  const used = new Set<number>();
  // сначала точные совпадения, затем вхождения
  for (const exact of [true, false]) {
    for (const f of FIELDS) {
      if (mapping[f.key] !== undefined) continue;
      const idx = headers.findIndex((h, i) => {
        if (used.has(i)) return false;
        const n = norm(String(h ?? ""));
        if (!n) return false;
        return f.synonyms.some((s) => (exact ? n === norm(s) : n.includes(norm(s)) && norm(s).length > 2));
      });
      if (idx >= 0) {
        mapping[f.key] = idx;
        used.add(idx);
      }
    }
  }
  return mapping;
}

function pad(n: number) {
  return String(n).padStart(2, "0");
}

function iso(y: number, m: number, d: number): string | null {
  if (y < 100) y += y > 40 ? 1900 : 2000;
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;
  return `${y}-${pad(m)}-${pad(d)}`;
}

/** Дата из ячейки: Date, серийный номер Excel, «31.12.2026», «31.12.26», «2026-12-31», «31/12/2026» */
export function parseDate(v: CellValue): string | null | "invalid" {
  if (v === null || v === undefined || v === "") return null;
  if (v instanceof Date) {
    if (Number.isNaN(v.getTime())) return "invalid";
    return `${v.getUTCFullYear()}-${pad(v.getUTCMonth() + 1)}-${pad(v.getUTCDate())}`;
  }
  if (typeof v === "number") {
    if (v > 20000 && v < 80000) {
      const ms = Math.round((v - 25569) * 86400000);
      const d = new Date(ms);
      return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
    }
    return "invalid";
  }
  const s = String(v).trim();
  let m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (m) return iso(+m[1], +m[2], +m[3]) ?? "invalid";
  m = s.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$/);
  if (m) return iso(+m[3], +m[2], +m[1]) ?? "invalid";
  return "invalid";
}

export function parseGender(v: CellValue): "male" | "female" | null {
  const s = norm(String(v ?? ""));
  if (!s) return null;
  if (/^(м|муж|мужской|male|m)$/.test(s)) return "male";
  if (/^(ж|жен|женский|female|f)$/.test(s)) return "female";
  return null;
}

export interface PreparedRow {
  row: number;             // номер строки в файле (с учётом заголовка)
  full_name: string;
  phone: string;
  email: string | null;
  birth_date: string | null;
  gender: "male" | "female" | null;
  source: string | null;
  tags: string[];
  note: string | null;
  plan_name: string | null;
  starts_on: string | null;
  ends_on: string | null;
  visits_left: number | null;
}

export interface LocalIssue { row: number; error: string }

const text = (v: CellValue): string => (v === null || v === undefined ? "" : v instanceof Date ? v.toISOString().slice(0, 10) : String(v).trim());

/** Готовит строки для import_clients. Явные ошибки (нет ФИО/телефона, кривая дата) отсекаются сразу с причиной. */
export function prepareRows(data: CellValue[][], mapping: Mapping, headerRow = true): { rows: PreparedRow[]; issues: LocalIssue[] } {
  const rows: PreparedRow[] = [];
  const issues: LocalIssue[] = [];
  const get = (r: CellValue[], k: FieldKey) => (mapping[k] === undefined ? undefined : r[mapping[k]!]);
  const body = headerRow ? data.slice(1) : data;
  body.forEach((r, i) => {
    const rowNo = i + (headerRow ? 2 : 1);
    if (!r || r.every((c) => text(c) === "")) return; // пустые строки пропускаем молча
    let name = text(get(r, "full_name"));
    if (!name) name = [get(r, "last_name"), get(r, "first_name"), get(r, "middle_name")].map(text).filter(Boolean).join(" ");
    const rawPhone = get(r, "phone");
    const phone = normalizePhone(typeof rawPhone === "number" ? String(Math.trunc(rawPhone)) : text(rawPhone));
    if (!name) return void issues.push({ row: rowNo, error: "Не указано ФИО" });
    if (!phone) return void issues.push({ row: rowNo, error: `Некорректный телефон: ${text(rawPhone) || "пусто"}` });
    const dates: Record<string, string | null> = {};
    for (const k of ["birth_date", "starts_on", "ends_on"] as const) {
      const d = parseDate(get(r, k));
      if (d === "invalid") return void issues.push({ row: rowNo, error: `Некорректная дата в колонке «${FIELDS.find((f) => f.key === k)!.label}»: ${text(get(r, k))}` });
      dates[k] = d;
    }
    const visitsRaw = text(get(r, "visits_left"));
    const visits = visitsRaw === "" ? null : Number(visitsRaw.replace(",", "."));
    if (visits !== null && (!Number.isInteger(visits) || visits < 0)) {
      return void issues.push({ row: rowNo, error: `Некорректное число визитов: ${visitsRaw}` });
    }
    rows.push({
      row: rowNo,
      full_name: name,
      phone,
      email: text(get(r, "email")) || null,
      birth_date: dates.birth_date,
      gender: parseGender(get(r, "gender")),
      source: text(get(r, "source")) || null,
      tags: text(get(r, "tags")).split(/[,;]/).map((t) => t.trim()).filter(Boolean),
      note: text(get(r, "note")) || null,
      plan_name: text(get(r, "plan_name")) || null,
      starts_on: dates.starts_on,
      ends_on: dates.ends_on,
      visits_left: visits,
    });
  });
  return { rows, issues };
}

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

export const TEMPLATE_HEADERS = ["ФИО", "Телефон", "Email", "Дата рождения", "Пол", "Источник", "Теги", "Заметка",
  "Абонемент", "Начало абонемента", "Окончание абонемента", "Осталось визитов"];
export const TEMPLATE_EXAMPLE = ["Иванова Мария Сергеевна", "+7 916 123-45-67", "maria@example.ru", "14.03.1992", "ж", "Instagram",
  "утро, пилатес", "Цель — спина", "Месяц", "01.09.2026", "30.09.2026", ""];
