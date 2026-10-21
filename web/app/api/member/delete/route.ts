import { apiError, dbError, memberFromRequest } from "@/lib/member-api";
import { createAdminClient } from "@/lib/supabase/admin";

// POST /api/member/delete — удаление аккаунта из приложения клиента (требование App Store и 152-ФЗ):
// записи клиента во всех залах обезличиваются, аккаунт входа удаляется. Оплаты остаются залу для бухгалтерии.
export async function POST(req: Request) {
  const member = await memberFromRequest(req);
  if (!member) return apiError(401, "UNAUTHORIZED", "Требуется вход");
  const { data: staff } = await member.db.from("staff").select("id").eq("user_id", member.user.id).limit(1);
  if (staff?.length) return apiError(403, "FORBIDDEN", "Аккаунт сотрудника удаляется из кабинета");
  const { data, error } = await member.db.rpc("request_account_deletion");
  if (error) return dbError(error);
  const { error: delError } = await createAdminClient().auth.admin.deleteUser(member.user.id);
  if (delError) return apiError(500, "INTERNAL", "Данные обезличены, но аккаунт не удалён — повторите запрос");
  return Response.json({ ...(data as object), account_deleted: true });
}
