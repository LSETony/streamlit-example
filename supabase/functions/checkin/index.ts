// POST /v1/checkin — проверить QR и записать визит (ресепшен, в будущем — турникеты).
// Ответ всегда 200 с полем ok: зелёный/красный экран и причина — это результат проверки, а не ошибка API.
import { ApiError, handler, json, readJson, requireUuid } from "../_shared/http.ts";
import { rpc, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте POST");
  const body = await readJson<{ gym_id?: string; qr?: string; client_id?: string }>(req);
  const client = userClient(req);
  if (body.client_id) {
    const result = await rpc(client, "checkin_manual", { p_client: requireUuid(body.client_id, "client_id") });
    return json(result);
  }
  const gymId = requireUuid(body.gym_id, "gym_id");
  if (typeof body.qr !== "string" || body.qr.length > 200) throw new ApiError(422, "INVALID_INPUT", "Передайте содержимое QR в поле qr");
  const result = await rpc(client, "checkin_qr", { p_gym: gymId, p_payload: body.qr });
  return json(result);
}));
