// GET /v1/gyms/{id}/occupancy — загруженность сейчас и прогноз по часам (без персональных данных)
import { ApiError, handler, json, pathParts, requireUuid } from "../_shared/http.ts";
import { rpc, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  const [id, action] = pathParts(req, "gyms");
  if (req.method === "GET" && id && action === "occupancy") {
    const result = await rpc(userClient(req), "gym_occupancy", { p_gym: requireUuid(id, "id") });
    return json(result);
  }
  throw new ApiError(404, "NOT_FOUND", "Метод не найден");
}));
