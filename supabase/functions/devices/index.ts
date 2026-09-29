// POST /v1/devices — зарегистрировать устройство: push-токен, выдать qr_secret.
// Секрет хранится в Keychain; при регистрации нового телефона секреты старых устройств отзываются.
import { ApiError, handler, json, readJson, UUID_RE } from "../_shared/http.ts";
import { rpc, userClient } from "../_shared/supabase.ts";

const PLATFORMS = ["ios", "android", "web", "telegram"];

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте POST");
  const body = await readJson<{ platform?: string; push_token?: string; device_id?: string }>(req);
  const platform = body.platform ?? "ios";
  if (!PLATFORMS.includes(platform)) throw new ApiError(422, "INVALID_INPUT", "Неизвестная платформа");
  if (body.device_id && !UUID_RE.test(body.device_id)) throw new ApiError(422, "INVALID_INPUT", "device_id должен быть UUID");
  const result = await rpc(userClient(req), "register_device", {
    p_platform: platform,
    p_push_token: body.push_token ?? null,
    p_device_id: body.device_id ?? null,
  });
  return json(result, 201);
}));
