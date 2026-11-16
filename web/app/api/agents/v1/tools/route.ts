import { agentFromRequest, agentTools, unauthorized } from "@/lib/ai/agent-api";

/** GET /api/agents/v1/tools — инструменты, доступные агенту по этому ключу */
export async function GET(req: Request) {
  const agent = await agentFromRequest(req);
  if (!agent) return unauthorized();
  return Response.json({
    agent: { id: agent.id, name: agent.name },
    tools: agentTools(agent).map((t) => ({ name: t.name, kind: t.kind, mode: t.mode, description: t.description, input_schema: t.inputSchema })),
  });
}
