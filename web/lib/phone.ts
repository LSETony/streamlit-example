// Приведение телефона к международному формату — та же логика, что public.normalize_phone в БД.
// Россия: 8 916…, 7 916…, 916… → +7…; ОАЭ: 050…, 50…, 971 50… → +971…
export function normalizePhone(input: string | null | undefined): string | null {
  if (!input) return null;
  const raw = String(input).trim();
  const d = raw.replace(/\D/g, "");
  if (!d) return null;
  if (d.length === 11 && (d[0] === "7" || d[0] === "8")) return "+7" + d.slice(1);
  if (d.length === 10 && d[0] === "9") return "+7" + d;
  if (d.length === 10 && d.startsWith("05")) return "+971" + d.slice(1);
  if (d.length === 9 && d[0] === "5") return "+971" + d;
  if (d.length === 12 && d.startsWith("971")) return "+" + d;
  if (raw.startsWith("+") && d.length >= 10 && d.length <= 15) return "+" + d;
  return null;
}
