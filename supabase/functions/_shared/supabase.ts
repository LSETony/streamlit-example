// Клиенты Supabase для Edge Functions.
// userClient — от имени вызывающего (JWT пользователя, работает RLS и проверки ролей в функциях БД);
// adminClient — service key, только для серверных операций (webhook, воркеры). Ключ не покидает сервер.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { ApiError, fromPgError } from "./http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export function userClient(req: Request): SupabaseClient {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) throw new ApiError(401, "UNAUTHORIZED", "Требуется вход");
  return createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

let admin: SupabaseClient | null = null;
export function adminClient(): SupabaseClient {
  admin ??= createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return admin;
}

// Текущий пользователь по JWT (проверяется Supabase Auth)
export async function requireUser(req: Request): Promise<{ id: string; phone?: string; email?: string }> {
  const client = userClient(req);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new ApiError(401, "UNAUTHORIZED", "Сессия истекла — войдите снова");
  return { id: data.user.id, phone: data.user.phone, email: data.user.email };
}

// Вызов функции БД с преобразованием ошибок в {code, message}
export async function rpc<T = unknown>(client: SupabaseClient, fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await client.rpc(fn, args);
  if (error) throw fromPgError(error);
  return data as T;
}

// Проверка секрета для служебных вызовов (cron, воркеры)
export function requireCronSecret(req: Request) {
  const expected = Deno.env.get("CRON_SECRET");
  const got = req.headers.get("x-cron-secret") ?? new URL(req.url).searchParams.get("secret");
  const auth = req.headers.get("Authorization");
  if (auth === `Bearer ${SERVICE_KEY}`) return;
  if (!expected || got !== expected) throw new ApiError(401, "UNAUTHORIZED", "Нужен секрет планировщика");
}
