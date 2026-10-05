// Форматирование для интерфейса: деньги в копейках, даты в часовом поясе зала, телефоны

const rubFmt = new Intl.NumberFormat("ru-RU", { maximumFractionDigits: 0 });
const rubFmt2 = new Intl.NumberFormat("ru-RU", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
const aedFmt = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });
const aedFmt2 = new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** Суммы хранятся в сотых долях валюты зала: 300000 → «3 000 ₽», 45000 в AED → «AED 450» (дробную часть показываем, только если она есть) */
export function money(minor: number | null | undefined, currency: string = "RUB"): string {
  if (minor === null || minor === undefined) return "—";
  const v = minor / 100;
  if (currency === "AED") return `AED ${Number.isInteger(v) ? aedFmt.format(v) : aedFmt2.format(v)}`;
  return `${Number.isInteger(v) ? rubFmt.format(v) : rubFmt2.format(v)} ₽`;
}

/** «3000», «3 000,50», «AED 1,200.50» → сотые доли валюты */
export function parseMoney(input: string): number | null {
  let clean = input.replace(/\s/g, "").replace(/₽|AED|руб\.?/gi, "");
  // запятая — разделитель тысяч, если после неё три цифры (1,200), иначе — дробной части (3000,50)
  clean = /,\d{3}(\D|$)/.test(clean) ? clean.replace(/,/g, "") : clean.replace(",", ".");
  if (!/^\d+(\.\d{1,2})?$/.test(clean)) return null;
  return Math.round(Number(clean) * 100);
}

/** Прежнее имя для рублей */
export const parseRub = parseMoney;

export function plural(n: number, one: string, few: string, many: string): string {
  const n10 = n % 10;
  const n100 = n % 100;
  if (n10 === 1 && n100 !== 11) return one;
  if (n10 >= 2 && n10 <= 4 && (n100 < 10 || n100 >= 20)) return few;
  return many;
}

/** Дата YYYY-MM-DD → «28.09.2026» */
export function date(d: string | null | undefined): string {
  if (!d) return "—";
  const [y, m, day] = d.slice(0, 10).split("-");
  return `${day}.${m}.${y}`;
}

/** Дата YYYY-MM-DD → «28 сент.» / «28 Sept» (intl — локаль языка кабинета) */
export function dateShort(d: string | null | undefined, intl = "ru-RU"): string {
  if (!d) return "—";
  const [y, m, day] = d.slice(0, 10).split("-").map(Number);
  return new Intl.DateTimeFormat(intl, { day: "numeric", month: "short", timeZone: "UTC" }).format(Date.UTC(y, m - 1, day));
}

/** timestamptz → «28.09.2026, 19:05» в часовом поясе зала */
export function dateTime(ts: string | null | undefined, tz: string): string {
  if (!ts) return "—";
  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit", timeZone: tz,
  }).format(new Date(ts));
}

export function time(ts: string | null | undefined, tz: string): string {
  if (!ts) return "—";
  return new Intl.DateTimeFormat("ru-RU", { hour: "2-digit", minute: "2-digit", timeZone: tz }).format(new Date(ts));
}

/** Сегодняшняя дата в часовом поясе зала, YYYY-MM-DD */
export function todayIn(tz: string, base: Date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", { year: "numeric", month: "2-digit", day: "2-digit", timeZone: tz }).format(base);
  return parts; // en-CA даёт YYYY-MM-DD
}

export function addDays(d: string, days: number): string {
  const [y, m, day] = d.split("-").map(Number);
  const dt = new Date(Date.UTC(y, m - 1, day + days));
  return dt.toISOString().slice(0, 10);
}

function utcDay(d: string): number {
  const [y, m, day] = d.slice(0, 10).split("-").map(Number);
  return Date.UTC(y, m - 1, day);
}

export function daysBetween(from: string, to: string): number {
  return Math.round((utcDay(to) - utcDay(from)) / 86400000);
}

/** Смещение часового пояса зала (минуты) для локального времени — для перевода «19:00 по залу» в UTC */
export function zonedToUtc(localDate: string, localTime: string, tz: string): Date {
  const [y, m, d] = localDate.split("-").map(Number);
  const [hh, mm] = localTime.split(":").map(Number);
  const guess = Date.UTC(y, m - 1, d, hh, mm);
  const offset = tzOffsetMinutes(new Date(guess), tz);
  return new Date(guess - offset * 60000);
}

export function tzOffsetMinutes(at: Date, tz: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit",
  }).formatToParts(at);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second"));
  return Math.round((asUtc - at.getTime()) / 60000);
}

/** +79161234567 → «+7 916 123-45-67», +971501234567 → «+971 50 123 4567» */
export function phone(p: string | null | undefined): string {
  if (!p) return "—";
  const ru = p.match(/^\+7(\d{3})(\d{3})(\d{2})(\d{2})$/);
  if (ru) return `+7 ${ru[1]} ${ru[2]}-${ru[3]}-${ru[4]}`;
  const ae = p.match(/^\+971(\d{1,2})(\d{3})(\d{4})$/);
  if (ae) return `+971 ${ae[1]} ${ae[2]} ${ae[3]}`;
  return p;
}

export function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join("");
}
