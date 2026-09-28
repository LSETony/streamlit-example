// Главный сервис edge-runtime: проверяет JWT и запускает нужную функцию из supabase/functions/<имя>.
// Функции без пользовательского JWT (webhook ЮKassa, воркеры, SMS-хук Auth) перечислены в NO_JWT — как verify_jwt=false в config.toml.
import * as jose from "npm:jose@5";

const JWT_SECRET = Deno.env.get("JWT_SECRET")!;
const NO_JWT = new Set(["payments", "notify", "maintenance", "sms-hook"]);

async function verify(req: Request): Promise<boolean> {
  const auth = req.headers.get("authorization");
  const token = auth?.startsWith("Bearer ") ? auth.slice(7) : null;
  if (!token) return false;
  try {
    await jose.jwtVerify(token, new TextEncoder().encode(JWT_SECRET));
    return true;
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const name = url.pathname.split("/")[1];
  if (!name || name === "main" || name.startsWith("_") || !/^[a-z0-9-]+$/.test(name)) {
    return Response.json({ code: "NOT_FOUND", message: "Функция не найдена" }, { status: 404 });
  }
  if (req.method !== "OPTIONS" && !NO_JWT.has(name) && !(await verify(req))) {
    return Response.json({ code: "UNAUTHORIZED", message: "Требуется вход" }, { status: 401 });
  }
  try {
    // @ts-ignore EdgeRuntime — глобальный объект supabase/edge-runtime
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `/home/deno/functions/${name}`,
      memoryLimitMb: 150,
      workerTimeoutMs: 60_000,
      noModuleCache: false,
      importMapPath: null,
      envVars: Object.entries(Deno.env.toObject()),
    });
    return await worker.fetch(req);
  } catch (e) {
    console.error("worker error", e);
    return Response.json({ code: "INTERNAL", message: "Внутренняя ошибка функции" }, { status: 500 });
  }
});
