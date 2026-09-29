// POST /v1/bookings — записаться на занятие (проверка мест и абонемента в БД под блокировкой)
// DELETE /v1/bookings/{id} — отменить запись (проверка срока отмены)
import { ApiError, handler, json, pathParts, readJson, requireUuid } from "../_shared/http.ts";
import { rpc, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  const client = userClient(req);
  const [id] = pathParts(req, "bookings");
  if (req.method === "POST" && !id) {
    const body = await readJson<{ schedule_item_id?: string; client_id?: string }>(req);
    const result = await rpc(client, "book_class", {
      p_item: requireUuid(body.schedule_item_id, "schedule_item_id"),
      p_client: body.client_id ? requireUuid(body.client_id, "client_id") : null,
    });
    return json(result, 201);
  }
  if (req.method === "DELETE" && id) {
    const result = await rpc(client, "cancel_booking", { p_booking: requireUuid(id, "id") });
    return json(result);
  }
  throw new ApiError(404, "NOT_FOUND", "Метод не найден");
}));
