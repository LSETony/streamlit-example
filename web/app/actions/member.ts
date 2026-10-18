"use server";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

/** Удаление аккаунта из приложения клиента: записи во всех залах обезличиваются, аккаунт входа удаляется */
export async function deleteMemberAccount(): Promise<ActionResult> {
  const supabase = await createClient();
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return fail({ code: "P0001", hint: "UNAUTHORIZED", message: "Требуется вход" });
  if (auth.user.email) return fail({ code: "P0001", hint: "FORBIDDEN", message: "Аккаунт сотрудника удаляется из кабинета" });
  const { error } = await supabase.rpc("request_account_deletion");
  if (error) return fail(error);
  const { error: delError } = await createAdminClient().auth.admin.deleteUser(auth.user.id);
  if (delError) return fail({ code: "P0001", hint: "INTERNAL", message: "Данные обезличены, но аккаунт не удалён — повторите запрос" });
  await supabase.auth.signOut();
  return ok(undefined);
}
