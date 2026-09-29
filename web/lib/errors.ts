// Ошибки функций БД приходят как {code: 'P0001', message, hint: 'MACHINE_CODE'} — приводим к {code, message}
export interface AppError {
  code: string;
  message: string;
}

export function toAppError(err: unknown): AppError {
  if (err && typeof err === "object") {
    const e = err as { code?: string; hint?: string | null; message?: string };
    if (e.code === "P0001" && e.hint) return { code: e.hint, message: e.message ?? "Ошибка" };
    if (e.code === "42501") return { code: "FORBIDDEN", message: "Недостаточно прав для этого действия" };
    if (e.code === "23505") return { code: "DUPLICATE", message: "Такая запись уже существует" };
    if (e.code === "23P01") return { code: "OVERLAP", message: "Период пересекается с уже существующим" };
    if (e.code === "PGRST116") return { code: "NOT_FOUND", message: "Запись не найдена" };
    if (typeof e.message === "string" && e.message) {
      if (e.message.includes("INVALID_PHONE") || e.hint === "INVALID_PHONE") return { code: "INVALID_PHONE", message: "Некорректный номер телефона" };
      if (/fetch failed|NetworkError|Failed to fetch/i.test(e.message)) {
        return { code: "NETWORK", message: "Нет связи с сервером. Проверьте интернет и повторите" };
      }
      return { code: e.code ?? "ERROR", message: e.message };
    }
  }
  return { code: "ERROR", message: "Что-то пошло не так. Попробуйте ещё раз" };
}

export type ActionResult<T = undefined> = { ok: true; data: T } | { ok: false; error: AppError };

export function ok<T>(data: T): ActionResult<T> {
  return { ok: true, data };
}

export function fail(err: unknown): { ok: false; error: AppError } {
  return { ok: false, error: toAppError(err) };
}
