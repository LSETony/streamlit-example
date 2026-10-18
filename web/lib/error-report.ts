/*
  Отчёты о серверных ошибках без SDK: Sentry (SENTRY_DSN, протокол envelope) и/или Telegram-чат команды
  (TELEGRAM_ALERT_BOT_TOKEN + TELEGRAM_ALERT_CHAT_ID — те же переменные, что у Edge Functions).
  Без переменных ничего не отправляется. Персональные данные не передаются: только путь, метод и текст ошибки.
*/

export interface ErrorInfo { message: string; stack?: string; digest?: string; path: string; method: string; route?: string }

/** https://<key>@<host>/<project> → адрес envelope и заголовок авторизации */
export function parseSentryDsn(dsn: string): { url: string; auth: string } | null {
  const m = dsn.match(/^(https?):\/\/([^@]+)@([^/]+)\/(?:(.*)\/)?(\d+)$/);
  if (!m) return null;
  const [, proto, key, host, path, project] = m;
  return {
    url: `${proto}://${host}/${path ? `${path}/` : ""}api/${project}/envelope/`,
    auth: `Sentry sentry_version=7, sentry_client=core-web/1.0, sentry_key=${key}`,
  };
}

export function sentryEnvelope(info: ErrorInfo, now = new Date()): string {
  const eventId = crypto.randomUUID().replace(/-/g, "");
  const event = {
    event_id: eventId,
    timestamp: now.toISOString(),
    platform: "node",
    level: "error",
    environment: process.env.VERCEL_ENV ?? process.env.NODE_ENV ?? "production",
    transaction: info.route ?? info.path.split("?")[0],
    tags: { method: info.method, digest: info.digest ?? "" },
    exception: { values: [{ type: "Error", value: info.message }] },
    extra: { stack: info.stack, path: info.path.split("?")[0] },
  };
  return [JSON.stringify({ event_id: eventId, sent_at: now.toISOString() }), JSON.stringify({ type: "event" }), JSON.stringify(event)].join("\n");
}

export async function reportError(info: ErrorInfo): Promise<void> {
  const jobs: Promise<unknown>[] = [];
  const sentry = process.env.SENTRY_DSN ? parseSentryDsn(process.env.SENTRY_DSN) : null;
  if (sentry) {
    jobs.push(fetch(sentry.url, {
      method: "POST",
      headers: { "Content-Type": "application/x-sentry-envelope", "X-Sentry-Auth": sentry.auth },
      body: sentryEnvelope(info),
    }));
  }
  const token = process.env.TELEGRAM_ALERT_BOT_TOKEN, chat = process.env.TELEGRAM_ALERT_CHAT_ID;
  if (token && chat) {
    jobs.push(fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chat, text: `core. ⚠️ ${info.method} ${info.path.split("?")[0]}\n${info.message}`.slice(0, 4000) }),
    }));
  }
  await Promise.allSettled(jobs);
}
