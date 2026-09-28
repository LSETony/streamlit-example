// Приведение телефона к формату +7XXXXXXXXXX — та же логика, что public.normalize_phone в БД
export function normalizePhone(input: string | null | undefined): string | null {
  if (!input) return null;
  const raw = String(input).trim();
  const d = raw.replace(/\D/g, "");
  if (!d) return null;
  if (d.length === 11 && (d[0] === "7" || d[0] === "8")) return "+7" + d.slice(1);
  if (d.length === 10 && d[0] === "9") return "+7" + d;
  if (raw.startsWith("+") && d.length >= 10 && d.length <= 15) return "+" + d;
  return null;
}
