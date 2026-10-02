import { EN, EN_PATTERNS } from "./en";

/*
  Языки кабинета: русский (основной) и английский.
  Ключ перевода — сам русский текст: t("Клиенты") → «Clients». Так строки остаются читаемыми в коде,
  а подписи из констант (разделы меню, роли, статусы) переводятся там, где выводятся: t(ROLE_LABEL[role]).
  Подстановки — {имя}: t("Показано {n} из {total}", { n, total }).
  Формы слова — t.n(5, "клиент|клиента|клиентов") → «клиентов» / «clients».
*/

export type Locale = "ru" | "en";
export const LOCALES: Locale[] = ["ru", "en"];
export const LOCALE_COOKIE = "core-lang";

export type Vars = Record<string, string | number>;

export interface T {
  (text: string, vars?: Vars): string;
  /** форма слова для числа: «клиент|клиента|клиентов» */
  n: (count: number, forms: string) => string;
  locale: Locale;
  /** локаль для Intl: даты, числа */
  intl: string;
}

function fill(text: string, vars?: Vars): string {
  if (!vars) return text;
  return text.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

function ruForm(n: number, forms: string[]): string {
  const [one, few = one, many = few] = forms;
  const n10 = Math.abs(n) % 10;
  const n100 = Math.abs(n) % 100;
  if (n10 === 1 && n100 !== 11) return one;
  if (n10 >= 2 && n10 <= 4 && (n100 < 10 || n100 >= 20)) return few;
  return many;
}

/** Перевод с запасным вариантом для «Текст: подробности» — переводится часть до двоеточия (сообщения с именами, кодами) */
function lookup(text: string): string {
  const hit = EN[text];
  if (hit !== undefined) return hit;
  for (const [re, en] of EN_PATTERNS) if (re.test(text)) return text.replace(re, en);
  const i = text.indexOf(": ");
  if (i > 0) {
    const head = EN[text.slice(0, i + 1)];
    if (head !== undefined) return head + text.slice(i + 1);
  }
  return text;
}

export function makeT(locale: Locale): T {
  const t = ((text: string, vars?: Vars) => fill(locale === "en" ? lookup(text) : text, vars)) as T;
  t.n = (count, forms) => {
    if (locale === "en") {
      const [one, other = one] = (EN[forms] ?? forms).split("|");
      return Math.abs(count) === 1 ? one : other;
    }
    return ruForm(count, forms.split("|"));
  };
  t.locale = locale;
  t.intl = locale === "en" ? "en-GB" : "ru-RU";
  return t;
}

export function isLocale(v: unknown): v is Locale {
  return v === "ru" || v === "en";
}

/** Язык без выбора пользователя — по заголовку Accept-Language браузера: русский, если он среди предпочтений, иначе английский */
export function localeFromAcceptLanguage(header: string | null): Locale {
  if (!header) return "ru";
  const langs = header.split(",").map((part) => part.trim().split(";")[0].toLowerCase());
  const first = langs[0] ?? "";
  if (first.startsWith("en")) return "en";
  if (langs.some((l) => /^(ru|uk|be|kk)/.test(l))) return "ru";
  return langs.length ? "en" : "ru";
}

/** Сообщения ошибок функций БД — по машинному коду (у самих сообщений текст на русском) */
export function errorText(t: T, err: { code?: string; message: string } | null | undefined): string {
  if (!err) return "";
  if (t.locale === "en" && err.code && EN[`error:${err.code}`]) return EN[`error:${err.code}`];
  return t(err.message);
}

/** Назначение платежа из БД («Абонемент «Месяц»») на языке кабинета */
export function paymentDescription(t: T, description: string | null | undefined): string {
  if (!description) return "";
  const m = description.match(/^Абонемент «(.+)»$/);
  return m ? t("Абонемент «{plan}»", { plan: m[1] }) : t(description);
}
