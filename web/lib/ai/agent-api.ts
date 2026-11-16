import "server-only";
import { createAdminClient } from "@/lib/supabase/admin";
import { AGENT_TOOLS, toolMode } from "./tools";
import { outcomeText, runAgentTool, type AgentRow, type ToolOutcome } from "./execute";

/*
  API для внешних ИИ-агентов (REST и MCP): запрос приходит с ключом агента (Authorization: Bearer core_ak_…).
  Агент видит только инструменты, включённые ему в кабинете, и действует от имени сотрудника, настроившего его.
*/
export async function agentFromRequest(req: Request): Promise<AgentRow | null> {
  const key = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "").trim() ?? "";
  if (!key.startsWith("core_ak_")) return null;
  const { data, error } = await createAdminClient().rpc("ai_agent_by_key", { p_key: key });
  if (error || !data) return null;
  const agent = data as AgentRow;
  return agent.enabled ? agent : null;
}

export function agentTools(agent: AgentRow) {
  return AGENT_TOOLS.filter((t) => toolMode(agent.tools, t.name) !== "off").map((t) => ({
    name: t.name, kind: t.kind, mode: toolMode(agent.tools, t.name), description: t.description, inputSchema: t.inputSchema,
  }));
}

export async function callAgentApiTool(agent: AgentRow, tool: string, args: unknown, reason?: unknown): Promise<ToolOutcome> {
  const input = args && typeof args === "object" && !Array.isArray(args) ? (args as Record<string, unknown>) : {};
  return runAgentTool(agent, tool, input, { reason: typeof reason === "string" ? reason : null });
}

export { outcomeText };

export function unauthorized(): Response {
  return Response.json({ code: "UNAUTHORIZED", message: "Invalid, revoked or disabled agent key" }, {
    status: 401, headers: { "WWW-Authenticate": 'Bearer realm="core-agents"' },
  });
}
