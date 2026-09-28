// POST /v1/memberships/{id}/freeze — заморозить абонемент (если зал разрешил заморозку из приложения)
import { ApiError, handler, json, optionalDate, pathParts, readJson, requireUuid } from "../_shared/http.ts";
import { rpc, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  const [id, action] = pathParts(req, "memberships");
  if (req.method === "POST" && id && action === "freeze") {
    const body = await readJson<{ from?: string; to?: string; reason?: string }>(req);
    const from = optionalDate(body.from, "from");
    const to = optionalDate(body.to, "to");
    if (!from || !to) throw new ApiError(422, "INVALID_INPUT", "Укажите даты from и to");
    const result = await rpc(userClient(req), "freeze_membership", {
      p_membership: requireUuid(id, "id"),
      p_from: from,
      p_to: to,
      p_reason: typeof body.reason === "string" ? body.reason.slice(0, 500) : null,
    });
    return json(result);
  }
  throw new ApiError(404, "NOT_FOUND", "Метод не найден");
}));
