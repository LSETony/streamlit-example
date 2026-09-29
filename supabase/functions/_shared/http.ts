// Общие HTTP-утилиты Edge Functions: CORS, JSON-ответы, единый формат ошибок {code, message}
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-api-version",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
};

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8" },
  });
}

export function errorResponse(status: number, code: string, message: string): Response {
  return json({ code, message }, status);
}

// HTTP-статус по машинному коду ошибки
export function statusForCode(code: string): number {
  if (code === "UNAUTHORIZED") return 401;
  if (code === "FORBIDDEN" || code === "GYM_READ_ONLY" || code === "FEATURE_DISABLED") return 403;
  if (code.endsWith("_NOT_FOUND")) return 404;
  if (["CLASS_FULL", "ALREADY_BOOKED", "MEMBERSHIP_OVERLAP", "REFUND_IN_PROGRESS", "FREEZE_OVERLAP"].includes(code)) return 409;
  if (code === "INTERNAL") return 500;
  return 422;
}

interface PgError {
  message: string;
  code?: string;
  hint?: string | null;
  details?: string | null;
}

// Ошибка PostgREST/PostgreSQL → ApiError. Бизнес-ошибки приходят с SQLSTATE P0001 и кодом в hint.
export function fromPgError(err: PgError): ApiError {
  if (err.code === "P0001" && err.hint) return new ApiError(statusForCode(err.hint), err.hint, err.message);
  if (err.code === "42501") return new ApiError(403, "FORBIDDEN", "Недостаточно прав для этого действия");
  if (err.code === "PGRST301" || err.code === "PGRST302") return new ApiError(401, "UNAUTHORIZED", "Требуется вход");
  if (err.code === "22P02") return new ApiError(422, "INVALID_INPUT", "Некорректные параметры запроса");
  console.error("database error", err);
  return new ApiError(500, "INTERNAL", "Внутренняя ошибка. Попробуйте ещё раз");
}

export async function readJson<T = Record<string, unknown>>(req: Request): Promise<T> {
  if (!req.body) return {} as T;
  try {
    return (await req.json()) as T;
  } catch {
    throw new ApiError(400, "INVALID_JSON", "Тело запроса должно быть JSON");
  }
}

// Части пути после имени функции: /functions/v1/bookings/123 → ["123"]
export function pathParts(req: Request, fn: string): string[] {
  const parts = new URL(req.url).pathname.split("/").filter(Boolean);
  const i = parts.lastIndexOf(fn);
  return i >= 0 ? parts.slice(i + 1) : parts;
}

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function requireUuid(value: unknown, field: string): string {
  if (typeof value !== "string" || !UUID_RE.test(value)) {
    throw new ApiError(422, "INVALID_INPUT", `Поле ${field} должно быть UUID`);
  }
  return value;
}

export function optionalDate(value: unknown, field: string): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new ApiError(422, "INVALID_INPUT", `Поле ${field} должно быть датой YYYY-MM-DD`);
  }
  return value;
}

// Обёртка обработчика: CORS preflight, перехват ошибок, единый формат ответа
export function handler(fn: (req: Request) => Promise<Response>): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
    const started = performance.now();
    try {
      const res = await fn(req);
      logRequest(req, res.status, started);
      return res;
    } catch (e) {
      const err = e instanceof ApiError ? e : new ApiError(500, "INTERNAL", "Внутренняя ошибка. Попробуйте ещё раз");
      if (!(e instanceof ApiError)) console.error("unhandled", e);
      logRequest(req, err.status, started, err.code);
      return errorResponse(err.status, err.code, err.message);
    }
  };
}

// Наблюдаемость: структурированный лог времени ответа и ошибок (раздел 7)
function logRequest(req: Request, status: number, started: number, code?: string) {
  const url = new URL(req.url);
  console.log(JSON.stringify({
    at: new Date().toISOString(),
    method: req.method,
    path: url.pathname,
    status,
    ms: Math.round(performance.now() - started),
    code,
  }));
}
