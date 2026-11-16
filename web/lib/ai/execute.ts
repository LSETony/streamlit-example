import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createAdminClient } from "@/lib/supabase/admin";
import { decryptSecret } from "@/lib/secrets";
import { sendWhatsappTemplate } from "@/lib/whatsapp";
import { toAppError, type AppError } from "@/lib/errors";
import { TOOL_BY_NAME, toolMode } from "./tools";

export interface AgentRow {
  id: string;
  gym_id: string;
  name: string;
  kind: "builtin" | "external";
  template: string;
  instructions: string;
  task: string;
  tools: Record<string, string>;
  schedule: "off" | "daily";
  enabled: boolean;
  acts_as: string | null;
  last_run_at: string | null;
}

export type ToolOutcome =
  | { status: "done"; result: unknown }
  | { status: "pending"; action_id: string; message: string }
  | { status: "error"; error: AppError };

const PENDING_MESSAGE =
  "The action is queued for approval by gym staff. Do not repeat it; tell the user it awaits approval.";

/**
 * Инструмент от имени агента. Чтение — сразу. Изменение — по режиму: approve ставит действие в очередь,
 * auto выполняет и записывает в журнал действий агента.
 */
export async function runAgentTool(agent: AgentRow, tool: string, args: Record<string, unknown>,
                                   opts: { runId?: string | null; reason?: string | null } = {}): Promise<ToolOutcome> {
  const def = TOOL_BY_NAME.get(tool);
  const mode = toolMode(agent.tools, tool);
  if (!def || mode === "off") return { status: "error", error: { code: "TOOL_DISABLED", message: "Этот инструмент агенту не разрешён" } };
  if (!agent.enabled) return { status: "error", error: { code: "AGENT_DISABLED", message: "Агент выключен" } };
  const admin = createAdminClient();
  if (def.kind === "read") return callAgentTool(admin, agent.id, tool, args);

  const { data: action, error } = await admin.from("ai_agent_actions").insert({
    gym_id: agent.gym_id, agent_id: agent.id, run_id: opts.runId ?? null, tool, args,
    reason: opts.reason?.slice(0, 500) ?? null, status: mode === "approve" ? "pending" : "running",
  }).select("id").single();
  if (error || !action) return { status: "error", error: toAppError(error) };
  if (mode === "approve") return { status: "pending", action_id: action.id, message: PENDING_MESSAGE };

  const out = tool === "send_whatsapp"
    ? await whatsappAsAgent(admin, agent, args)
    : await callAgentTool(admin, agent.id, tool, args);
  await admin.from("ai_agent_actions").update(out.status === "done"
    ? { status: "executed", result: out.result ?? null }
    : { status: "failed", error: out.status === "error" ? out.error.message : null }).eq("id", action.id);
  return out;
}

async function callAgentTool(admin: SupabaseClient, agentId: string, tool: string, args: Record<string, unknown>): Promise<ToolOutcome> {
  const { data, error } = await admin.rpc("agent_tool", { p_agent: agentId, p_tool: tool, p_args: args });
  if (error) return { status: "error", error: toAppError(error) };
  return { status: "done", result: data };
}

interface WhatsappTarget { phone: string | null; full_name: string; consent_marketing_at: string | null }

/** Отправка шаблона WhatsApp клиенту зала; клиент без согласия на рассылки пропускается */
export async function sendWhatsappToClient(admin: SupabaseClient, gymId: string, clientId: string): Promise<{ ok: true } | { ok: false; error: AppError }> {
  const [{ data: sec }, { data: gym }, { data: client }] = await Promise.all([
    admin.from("gym_secrets").select("whatsapp_phone_id, whatsapp_token_encrypted, whatsapp_template, whatsapp_lang").eq("gym_id", gymId).maybeSingle(),
    admin.from("gyms").select("name, region").eq("id", gymId).single(),
    admin.from("clients").select("phone, full_name, consent_marketing_at").eq("id", clientId).eq("gym_id", gymId).is("deleted_at", null).maybeSingle(),
  ]);
  if (!sec?.whatsapp_phone_id || !sec.whatsapp_token_encrypted || !sec.whatsapp_template) {
    return { ok: false, error: { code: "WHATSAPP_NOT_CONNECTED", message: "WhatsApp Business не подключён. Подключите его в настройках зала" } };
  }
  const c = client as WhatsappTarget | null;
  if (!c) return { ok: false, error: { code: "CLIENT_NOT_FOUND", message: "Клиент не найден" } };
  if (!c.consent_marketing_at) return { ok: false, error: { code: "NO_MARKETING_CONSENT", message: "Клиент не давал согласия на рассылки" } };
  if (!c.phone) return { ok: false, error: { code: "NO_PHONE", message: "У клиента не указан телефон" } };
  const firstName = gym?.region === "AE" ? c.full_name.split(" ")[0] : (c.full_name.split(" ")[1] ?? c.full_name);
  const r = await sendWhatsappTemplate(
    { phoneId: sec.whatsapp_phone_id, token: decryptSecret(sec.whatsapp_token_encrypted), template: sec.whatsapp_template, lang: sec.whatsapp_lang ?? "en" },
    c.phone, [firstName, gym?.name ?? ""]);
  if (!r.ok) return { ok: false, error: { code: "WHATSAPP_FAILED", message: r.error } };
  return { ok: true };
}

async function whatsappAsAgent(admin: SupabaseClient, agent: AgentRow, args: Record<string, unknown>): Promise<ToolOutcome> {
  // права, клиент этого зала и согласие на рассылки проверяет БД — до отправки
  const check = await callAgentTool(admin, agent.id, "send_whatsapp", { ...args, stage: "check" });
  if (check.status !== "done") return check;
  const sent = await sendWhatsappToClient(admin, agent.gym_id, String(args.client_id));
  if (!sent.ok) return { status: "error", error: sent.error };
  return callAgentTool(admin, agent.id, "send_whatsapp", { ...args, stage: "log" });
}

/** Результат инструмента в виде текста для модели или внешнего агента */
export function outcomeText(out: ToolOutcome): string {
  const raw = out.status === "done" ? JSON.stringify(out.result ?? null)
    : out.status === "pending" ? JSON.stringify({ status: "pending_approval", action_id: out.action_id, message: out.message })
      : JSON.stringify({ error: out.error.code, message: out.error.message });
  return raw.length > 30000 ? raw.slice(0, 30000) + "…(truncated)" : raw;
}
