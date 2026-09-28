// Фоновое обслуживание (если в базе нет pg_cron): истёкшие абонементы, заморозки, автовыход,
// напоминания об окончании абонемента. Вызывается планировщиком раз в 15 минут.
import { ApiError, handler, json } from "../_shared/http.ts";
import { adminClient, requireCronSecret, rpc } from "../_shared/supabase.ts";
import { alertTeam } from "../_shared/alert.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте POST");
  requireCronSecret(req);
  try {
    return json(await rpc(adminClient(), "run_maintenance"));
  } catch (e) {
    await alertTeam(`Ночное задание упало: ${e instanceof Error ? e.message : e}`);
    throw e;
  }
}));
