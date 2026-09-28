// DELETE /v1/me — запрос на удаление аккаунта и данных (152-ФЗ).
// Записи клиента во всех залах обезличиваются (оплаты остаются залу для бухгалтерии), аккаунт удаляется.
import { ApiError, handler, json } from "../_shared/http.ts";
import { adminClient, requireUser, rpc, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "DELETE") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте DELETE");
  const user = await requireUser(req);
  const result = await rpc<{ anonymized_clients: number }>(userClient(req), "request_account_deletion");
  const { error } = await adminClient().auth.admin.deleteUser(user.id);
  if (error) {
    console.error("delete user failed", error);
    throw new ApiError(500, "INTERNAL", "Данные обезличены, но аккаунт не удалён — повторите запрос");
  }
  return json({ ...result, account_deleted: true });
}));
