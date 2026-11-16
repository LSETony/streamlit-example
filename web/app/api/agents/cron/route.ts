import { createAdminClient } from "@/lib/supabase/admin";
import { todayIn } from "@/lib/format";
import { agentsConfigured, runBuiltinAgent } from "@/lib/ai/runner";
import type { AgentRow } from "@/lib/ai/execute";

// Ежедневный запуск встроенных агентов с расписанием (Vercel Cron, см. vercel.json).
export const maxDuration = 300;

export async function GET(req: Request) {
  const secret = process.env.CRON_SECRET;
  if (!secret || req.headers.get("authorization") !== `Bearer ${secret}`) {
    return Response.json({ code: "UNAUTHORIZED" }, { status: 401 });
  }
  if (!agentsConfigured()) return Response.json({ ran: 0, skipped: "ANTHROPIC_API_KEY is not set" });
  const admin = createAdminClient();
  const since = new Date(Date.now() - 20 * 3600 * 1000).toISOString();
  const { data: agents } = await admin.from("ai_agents").select("*, gyms(timezone, trial_until, paid_until, is_demo)")
    .eq("kind", "builtin").eq("schedule", "daily").eq("enabled", true).neq("task", "")
    .or(`last_run_at.is.null,last_run_at.lt.${since}`).order("last_run_at", { ascending: true, nullsFirst: true }).limit(50);
  const started = Date.now();
  let ran = 0;
  for (const a of agents ?? []) {
    if (Date.now() - started > 200_000) break; // остальные — при следующем запуске
    const g = a.gyms as { timezone: string; trial_until: string; paid_until: string | null; is_demo: boolean } | null;
    if (!g || g.is_demo) continue;
    const today = todayIn(g.timezone);
    if (g.trial_until < today && (!g.paid_until || g.paid_until < today)) continue;
    const { gyms: _gym, ...agent } = a;
    void _gym;
    await runBuiltinAgent(agent as AgentRow, (agent as AgentRow).task, "schedule", null);
    ran++;
  }
  return Response.json({ ran });
}
