import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { ANON_KEY, SESSION_COOKIE, serverUrl } from "./config";

// Клиент Supabase на сервере от имени вошедшего сотрудника: работают RLS и проверки ролей в функциях БД
export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(serverUrl(), ANON_KEY, {
    cookieOptions: { name: SESSION_COOKIE },
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // вызов из Server Component — сессию обновит proxy
        }
      },
    },
  });
}
