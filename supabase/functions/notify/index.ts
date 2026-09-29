// Воркер уведомлений (раздел 5.9): забирает очередь notifications_outbox и отправляет
// push в приложение, а клиентам без приложения — SMS или email (по настройке зала).
// Вызывается планировщиком каждую минуту. Согласия и «тихие часы» проверяются ещё раз перед отправкой.
import { ApiError, handler, json } from "../_shared/http.ts";
import { adminClient, requireCronSecret, rpc } from "../_shared/supabase.ts";
import { emailConfigured, pushConfigured, sendEmail, sendPush, sendSms, smsConfigured, type SendResult } from "../_shared/push.ts";
import { alertTeam } from "../_shared/alert.ts";

interface Job {
  id: string;
  kind: string;
  service: boolean;
  title: string;
  body: string;
  data: Record<string, unknown>;
  attempts: number;
  client: { id: string; user_id: string | null; phone: string | null; email: string | null; marketing_ok: boolean; deleted: boolean };
  gym: { id: string; name: string; timezone: string; fallback: "sms" | "email" | "none" };
  push_tokens: string[];
}

function localHour(tz: string): number {
  return Number(new Intl.DateTimeFormat("en-GB", { hour: "2-digit", hour12: false, timeZone: tz }).format(new Date()));
}

async function deliver(job: Job): Promise<{ status: "sent" | "skipped" | "failed"; channel?: string; error?: string }> {
  if (job.client.deleted) return { status: "skipped", error: "client deleted" };
  if (!job.service && !job.client.marketing_ok) return { status: "skipped", error: "no marketing consent" };
  const hour = localHour(job.gym.timezone);
  if (hour >= 22 || hour < 9) return { status: "failed", error: "quiet hours" }; // вернётся в очередь

  // 1. Push, если клиент в приложении
  if (job.push_tokens.length && pushConfigured()) {
    let delivered = false;
    const errors: string[] = [];
    for (const token of job.push_tokens) {
      const r: SendResult = await sendPush(token, job.title, job.body, { kind: job.kind, ...job.data });
      if (r.ok) delivered = true;
      else {
        errors.push(r.error);
        if (r.permanent) {
          await adminClient().from("client_devices").update({ push_token: null }).eq("push_token", token);
        }
      }
    }
    if (delivered) return { status: "sent", channel: "push" };
    if (job.client.user_id && errors.length === 0) return { status: "failed", channel: "push", error: "push failed" };
  }

  // 2. Клиентам без приложения — SMS или email по настройке зала
  const text = `${job.gym.name}: ${job.body}`;
  if (job.gym.fallback === "sms" && job.client.phone && smsConfigured()) {
    const r = await sendSms(job.client.phone, text);
    return r.ok ? { status: "sent", channel: "sms" } : { status: "failed", channel: "sms", error: r.error };
  }
  if (job.gym.fallback === "email" && job.client.email && emailConfigured()) {
    const r = await sendEmail(job.client.email, job.title, text, job.gym.name);
    return r.ok ? { status: "sent", channel: "email" } : { status: "failed", channel: "email", error: r.error };
  }
  return { status: "skipped", error: "no delivery channel" };
}

Deno.serve(handler(async (req) => {
  if (req.method !== "POST") throw new ApiError(405, "METHOD_NOT_ALLOWED", "Используйте POST");
  requireCronSecret(req);
  const admin = adminClient();
  const stats = { sent: 0, skipped: 0, failed: 0 };
  for (let round = 0; round < 10; round++) {
    const jobs = await rpc<Job[]>(admin, "claim_notifications", { p_limit: 50 });
    if (!jobs?.length) break;
    await Promise.all(jobs.map(async (job) => {
      let res: Awaited<ReturnType<typeof deliver>>;
      try {
        res = await deliver(job);
      } catch (e) {
        res = { status: "failed", error: e instanceof Error ? e.message : String(e) };
      }
      stats[res.status]++;
      await rpc(admin, "complete_notification", {
        p_id: job.id, p_status: res.status, p_channel: res.channel ?? null, p_error: res.error ?? null,
      });
    }));
  }
  if (stats.failed > 20) await alertTeam(`Уведомления: ${stats.failed} неудачных отправок за запуск`);
  return json(stats);
}));
