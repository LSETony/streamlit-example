"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { Check, X } from "lucide-react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { dateTime } from "@/lib/format";
import { TOOL_BY_NAME } from "@/lib/ai/tools";
import { approveAgentAction, rejectAgentAction } from "@/app/actions/agents";
import { useT } from "@/lib/i18n/client";

export interface ActionRow {
  id: string;
  agent_id: string;
  agent_name: string;
  client_name?: string | null;
  tool: string;
  args: Record<string, unknown>;
  reason: string | null;
  status: "pending" | "running" | "executed" | "rejected" | "failed";
  error: string | null;
  created_at: string;
}

const STATUS: Record<ActionRow["status"], { label: string; variant: "warning" | "info" | "success" | "outline" | "danger" }> = {
  pending: { label: "Ждёт подтверждения", variant: "warning" },
  running: { label: "Выполняется", variant: "info" },
  executed: { label: "Выполнено", variant: "success" },
  rejected: { label: "Отклонено", variant: "outline" },
  failed: { label: "Ошибка", variant: "danger" },
};

// Параметры действия, понятные сотруднику (идентификаторы не показываем)
const DETAIL_KEYS = ["text", "note", "channel", "from", "to", "reason"] as const;

export function ActionQueue({ rows, timezone, readOnly }: { rows: ActionRow[]; timezone: string; readOnly: boolean }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const decide = (fn: () => Promise<{ ok: boolean; error?: { message: string } }>, done: string) => start(async () => {
    const r = await fn();
    if (!r.ok) toast.error(r.error!.message); else toast.success(done);
    router.refresh();
  });
  return (
    <div className="grid gap-2">
      {rows.map((a) => {
        const def = TOOL_BY_NAME.get(a.tool);
        const s = STATUS[a.status];
        const details = DETAIL_KEYS.filter((k) => typeof a.args?.[k] === "string" && a.args[k]).map((k) => String(a.args[k]));
        return (
          <Card key={a.id} className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center">
            <div className="grid min-w-0 flex-1 gap-1">
              <div className="flex flex-wrap items-center gap-2">
                <p className="font-medium">{t(def?.label ?? a.tool)}</p>
                {a.client_name ? <Link href={`/clients/${String(a.args.client_id)}`} className="text-sm text-tint-text hover:underline">{a.client_name}</Link> : null}
                <Badge variant={s.variant}>{s.label}</Badge>
              </div>
              {details.length ? <p className="text-sm">{details.join(" · ")}</p> : null}
              {a.error ? <p className="text-sm text-destructive">{t(a.error)}</p> : null}
              <p className="text-xs text-muted-foreground">
                <Link href={`/agents/${a.agent_id}`} className="hover:underline">{a.agent_name}</Link> · {dateTime(a.created_at, timezone)}
                {a.reason ? ` · ${a.reason.slice(0, 140)}` : ""}
              </p>
            </div>
            {a.status === "pending" && !readOnly ? (
              <div className="flex shrink-0 gap-2">
                <Button size="sm" variant="outline" disabled={pending} onClick={() => decide(() => rejectAgentAction(a.id), "Действие отклонено")}><X /> Отклонить</Button>
                <Button size="sm" disabled={pending} onClick={() => decide(() => approveAgentAction(a.id), "Действие выполнено")}><Check /> Подтвердить</Button>
              </div>
            ) : null}
          </Card>
        );
      })}
    </div>
  );
}
