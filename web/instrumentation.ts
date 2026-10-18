import type { Instrumentation } from "next";
import { reportError } from "@/lib/error-report";

// Серверные ошибки кабинета → Sentry и/или Telegram команды (если заданы переменные окружения)
export const onRequestError: Instrumentation.onRequestError = async (err, request, context) => {
  const e = err as { message?: string; stack?: string; digest?: string };
  await reportError({
    message: e?.message ?? String(err),
    stack: e?.stack,
    digest: e?.digest,
    path: request.path,
    method: request.method,
    route: context.routePath,
  });
};
