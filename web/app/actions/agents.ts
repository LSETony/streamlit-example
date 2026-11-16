"use server";
import { revalidatePath } from "next/cache";
import { callRpc } from "@/lib/actions";
import { ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { AGENT_TOOLS, type ToolMode } from "@/lib/ai/tools";
import { sendWhatsappToClient, type AgentRow } from "@/lib/ai/execute";
import { agentsConfigured, runBuiltinAgent, type RunStep } from "@/lib/ai/runner";

const READ_ONLY = { ok: false as const, error: { code: "GYM_READ_ONLY", message: "Кабинет в режиме «только чтение»" } };

export interface AgentInput {
  id: string | null;
  name: string;
  kind: "builtin" | "external";
  template: string;
  instructions: string;
  task: string;
  tools: Record<string, ToolMode>;
  schedule: "off" | "daily";
  enabled: boolean;
}

export async function saveAgent(input: AgentInput): Promise<ActionResult<string>> {
  const ctx = await requireStaff(["owner", "admin"]);
  if (ctx.readOnly) return READ_ONLY;
  const tools = Object.fromEntries(AGENT_TOOLS.map((t) => [t.name, input.tools[t.name] ?? "off"]));
  const res = await callRpc<string>("ai_agent_save", {
    p_gym: ctx.gym.id, p_agent: input.id, p_name: input.name, p_kind: input.kind, p_template: input.template,
    p_instructions: input.instructions, p_task: input.task, p_tools: tools,
    p_schedule: input.kind === "builtin" ? input.schedule : "off", p_enabled: input.enabled,
  });
  if (res.ok) revalidatePath("/agents");
  return res;
}

export async function deleteAgent(id: string): Promise<ActionResult<null>> {
  await requireStaff(["owner", "admin"]);
  const res = await callRpc<null>("ai_agent_delete", { p_agent: id });
  if (res.ok) revalidatePath("/agents");
  return res;
}

export async function createAgentKey(agentId: string): Promise<ActionResult<string>> {
  const ctx = await requireStaff(["owner", "admin"]);
  if (ctx.readOnly) return READ_ONLY;
  const res = await callRpc<string>("ai_agent_create_key", { p_agent: agentId });
  if (res.ok) revalidatePath(`/agents/${agentId}`);
  return res;
}

export async function revokeAgentKey(keyId: string, agentId: string): Promise<ActionResult<null>> {
  await requireStaff(["owner", "admin"]);
  const res = await callRpc<null>("ai_agent_revoke_key", { p_key: keyId });
  if (res.ok) revalidatePath(`/agents/${agentId}`);
  return res;
}

/** Запуск встроенного агента с заданием из кабинета */
export async function runAgent(agentId: string, prompt: string): Promise<ActionResult<{ output: string; steps: RunStep[]; status: "done" | "failed"; error?: string }>> {
  const ctx = await requireStaff(["owner", "admin"]);
  if (ctx.readOnly) return READ_ONLY;
  if (!agentsConfigured()) {
    return { ok: false, error: { code: "AI_NOT_CONFIGURED", message: "Встроенные агенты не подключены: на сервере не задан ANTHROPIC_API_KEY" } };
  }
  const text = prompt.trim();
  if (!text) return { ok: false, error: { code: "INVALID_INPUT", message: "Напишите задание для агента" } };
  const supabase = await createClient();
  const { data: agent } = await supabase.from("ai_agents").select("*").eq("id", agentId).eq("gym_id", ctx.gym.id).maybeSingle();
  if (!agent) return { ok: false, error: { code: "AGENT_NOT_FOUND", message: "Агент не найден" } };
  if (agent.kind !== "builtin") return { ok: false, error: { code: "INVALID_INPUT", message: "Внешний агент запускается своей программой по API-ключу" } };
  if (!agent.enabled) return { ok: false, error: { code: "AGENT_DISABLED", message: "Агент выключен" } };
  const r = await runBuiltinAgent(agent as AgentRow, text.slice(0, 4000), "manual", ctx.userId);
  revalidatePath(`/agents/${agentId}`);
  revalidatePath("/agents");
  return ok({ output: r.output, steps: r.steps, status: r.status, error: r.error });
}

/** Подтвердить действие агента: сотрудник выполняет его от своего имени */
export async function approveAgentAction(actionId: string): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner", "admin"]);
  if (ctx.readOnly) return READ_ONLY;
  const claim = await callRpc<{ id: string; gym_id: string; tool: string; args: Record<string, unknown> }>("ai_action_claim", { p_action: actionId });
  if (!claim.ok) return claim;
  const { tool, args, gym_id } = claim.data;
  let res: ActionResult<unknown>;
  if (tool === "send_whatsapp") {
    res = await callRpc("ai_tool", { p_gym: gym_id, p_tool: tool, p_args: { ...args, stage: "check" } });
    if (res.ok) {
      const sent = await sendWhatsappToClient(createAdminClient(), gym_id, String(args.client_id));
      res = sent.ok ? await callRpc("ai_tool", { p_gym: gym_id, p_tool: tool, p_args: { ...args, stage: "log" } }) : sent;
    }
  } else {
    res = await callRpc("ai_tool", { p_gym: gym_id, p_tool: tool, p_args: args });
  }
  await callRpc("ai_action_finish", {
    p_action: actionId, p_ok: res.ok, p_result: res.ok ? (res.data ?? null) : null, p_error: res.ok ? null : res.error.message,
  });
  revalidatePath("/agents");
  if (!res.ok) return res;
  return ok(null);
}

export async function rejectAgentAction(actionId: string): Promise<ActionResult<null>> {
  await requireStaff(["owner", "admin"]);
  const res = await callRpc<null>("ai_action_reject", { p_action: actionId });
  if (res.ok) revalidatePath("/agents");
  return res;
}
