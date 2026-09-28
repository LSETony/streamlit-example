import "server-only";
import { createClient } from "@supabase/supabase-js";

// Service key — только на сервере (раздел 7: «никогда в коде кабинета»). Используется для приглашения
// сотрудников, создания залов командой core. и сохранения ключей ЮKassa — после проверки прав вызывающего.
export function createAdminClient() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) throw new Error("SUPABASE_SERVICE_ROLE_KEY не задан");
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
