import "server-only";
import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import { ANON_KEY, serverUrl } from "@/lib/supabase/config";

/*
  API для мобильного приложения клиента: запрос приходит с токеном входа Supabase (Authorization: Bearer …),
  все вызовы БД идут от имени клиента — работают те же права и проверки, что и в приложении.
*/
export async function memberFromRequest(req: Request): Promise<{ user: User; db: SupabaseClient; token: string } | null> {
  const token = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;
  const db = createClient(serverUrl(), ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data } = await db.auth.getUser(token);
  return data.user ? { user: data.user, db, token } : null;
}

export function apiError(status: number, code: string, message: string): Response {
  return Response.json({ code, message }, { status });
}

/** Ошибка функции БД {code: P0001, hint, message} → ответ API {code, message} */
export function dbError(error: { code?: string; hint?: string | null; message?: string }): Response {
  const code = error.code === "P0001" && error.hint ? error.hint : "ERROR";
  const status = code === "FORBIDDEN" ? 403 : code.endsWith("NOT_FOUND") ? 404 : 422;
  return apiError(status, code, error.message ?? "Ошибка");
}
