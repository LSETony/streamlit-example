import { agentFromRequest, callAgentApiTool, unauthorized } from "@/lib/ai/agent-api";

/**
 * POST /api/agents/v1/tools/{tool} — вызов инструмента: {"arguments": {...}, "reason": "зачем"}.
 * 200 — результат, 202 — действие ждёт подтверждения сотрудника, 403/422 — запрещено или ошибка.
 */
export async function POST(req: Request, ctx: RouteContext<"/api/agents/v1/tools/[tool]">) {
  const agent = await agentFromRequest(req);
  if (!agent) return unauthorized();
  const { tool } = await ctx.params;
  const body = (await req.json().catch(() => ({}))) as { arguments?: unknown; reason?: unknown };
  const out = await callAgentApiTool(agent, tool, body.arguments ?? {}, body.reason);
  if (out.status === "done") return Response.json({ status: "done", result: out.result });
  if (out.status === "pending") return Response.json({ status: "pending_approval", action_id: out.action_id, message: out.message }, { status: 202 });
  const status = ["TOOL_DISABLED", "FORBIDDEN", "AGENT_DISABLED", "AGENT_OWNER_GONE"].includes(out.error.code) ? 403
    : out.error.code.endsWith("NOT_FOUND") ? 404 : 422;
  return Response.json({ status: "error", code: out.error.code, message: out.error.message }, { status });
}
