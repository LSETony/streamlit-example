"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { Copy, KeyRound } from "lucide-react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert } from "@/components/ui/misc";
import { dateTime } from "@/lib/format";
import { createAgentKey, revokeAgentKey } from "@/app/actions/agents";
import { useT } from "@/lib/i18n/client";

export interface KeyRow { id: string; prefix: string; created_at: string; last_used_at: string | null; revoked_at: string | null }

function Code({ children }: { children: string }) {
  return (
    <div className="relative">
      <pre className="overflow-x-auto rounded-2xl bg-field p-3 pr-11 text-xs leading-relaxed"><code>{children}</code></pre>
      <button type="button" className="absolute right-2 top-2 grid size-8 cursor-pointer place-items-center rounded-full text-tint-text hover:bg-field-hover"
        onClick={() => navigator.clipboard.writeText(children).then(() => toast.success("Скопировано"))} aria-label="Copy"><Copy className="size-4" /></button>
    </div>
  );
}

export function KeysPanel({ agentId, keys, origin, timezone, readOnly }: {
  agentId: string; keys: KeyRow[]; origin: string; timezone: string; readOnly: boolean;
}) {
  const t = useT();
  const router = useRouter();
  const [fresh, setFresh] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const key = fresh ?? "core_ak_…";
  const create = () => start(async () => {
    const r = await createAgentKey(agentId);
    if (!r.ok) { toast.error(r.error.message); return; }
    setFresh(r.data);
    router.refresh();
  });
  const revoke = (id: string) => start(async () => {
    if (!confirm(t("Отозвать ключ? Агент с этим ключом сразу потеряет доступ."))) return;
    const r = await revokeAgentKey(id, agentId);
    if (!r.ok) { toast.error(r.error.message); return; }
    router.refresh();
  });
  const mcpConfig = JSON.stringify({ mcpServers: { core: { type: "http", url: `${origin}/api/agents/mcp`, headers: { Authorization: `Bearer ${key}` } } } }, null, 2);
  return (
    <div className="grid gap-4">
      <Card>
        <CardHeader>
          <CardTitle>API-ключи</CardTitle>
          <CardDescription>Ключ даёт внешнему агенту доступ только к инструментам, включённым в правах. Храните его как пароль.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3">
          {fresh ? (
            <Alert variant="success">
              <p className="mb-2 font-medium">{t("Ключ создан. Скопируйте его сейчас — больше он показан не будет.")}</p>
              <Code>{fresh}</Code>
            </Alert>
          ) : null}
          {keys.map((k) => (
            <div key={k.id} className={`flex flex-wrap items-center gap-2 text-sm ${k.revoked_at ? "opacity-60" : ""}`}>
              <KeyRound className="size-4 text-muted-foreground" />
              <code className="font-mono">{k.prefix}…</code>
              {k.revoked_at ? <Badge variant="outline">Отозван</Badge> : <Badge variant="success">Действует</Badge>}
              <span className="flex-1 text-xs text-muted-foreground">
                {k.last_used_at ? t("Использован {at}", { at: dateTime(k.last_used_at, timezone) }) : t("Ещё не использовался")}
              </span>
              {!k.revoked_at ? <Button size="sm" variant="ghost" onClick={() => revoke(k.id)} disabled={pending}>Отозвать</Button> : null}
            </div>
          ))}
          <div><Button onClick={create} disabled={pending || readOnly}><KeyRound /> Создать ключ</Button></div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Подключение</CardTitle>
          <CardDescription>Через MCP — для Claude, ChatGPT, Cursor и других клиентов MCP. Через REST — для n8n, Make, Zapier и своего кода.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3">
          <p className="text-sm font-medium">MCP (Streamable HTTP)</p>
          <Code>{mcpConfig}</Code>
          <p className="text-sm font-medium">REST</p>
          <Code>{`# ${t("список доступных инструментов")}\ncurl ${origin}/api/agents/v1/tools -H "Authorization: Bearer ${key}"\n\n# ${t("вызов инструмента")}\ncurl -X POST ${origin}/api/agents/v1/tools/risk_clients \\\n  -H "Authorization: Bearer ${key}" -H "Content-Type: application/json" \\\n  -d '{"arguments": {"limit": 10}}'`}</Code>
          <p className="text-xs text-muted-foreground">{t("Действия «с подтверждением» возвращают status: pending_approval и ждут сотрудника в разделе «ИИ-агенты».")}</p>
        </CardContent>
      </Card>
    </div>
  );
}
