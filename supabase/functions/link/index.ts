// POST /v1/link — привязать аккаунт приложения к клиентам залов по номеру телефона
import { ApiError, handler, json } from "../_shared/http.ts";
import { rpc, userClient } from "../_shared/supabase.ts";

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте POST");
  const result = await rpc(userClient(req), "link_account");
  return json(result);
}));
