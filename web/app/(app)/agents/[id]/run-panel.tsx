"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { Play } from "lucide-react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Textarea } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { dateTime } from "@/lib/format";
import { TOOL_BY_NAME } from "@/lib/ai/tools";
import { runAgent } from "@/app/actions/agents";
import { useT } from "@/lib/i18n/client";

interface Step { tool: string; status: "done" | "pending" | "error"; summary: string }
export interface RunRow {
  id: string; source: "manual" | "schedule"; prompt: string; output: string | null; steps: Step[];
  status: "running" | "done" | "failed"; error: string | null; created_at: string;
}

const STEP_VARIANT = { done: "success", pending: "warning", error: "danger" } as const;
const STEP_LABEL = { done: "выполнено", pending: "ждёт подтверждения", error: "ошибка" } as const;

function Steps({ steps }: { steps: Step[] }) {
  const t = useT();
  if (!steps?.length) return null;
  return (
    <ul className="grid gap-1">
      {steps.map((s, i) => (
        <li key={i} className="flex flex-wrap items-center gap-2 text-xs">
          <span className="font-medium">{t(TOOL_BY_NAME.get(s.tool)?.label ?? s.tool)}</span>
          <Badge variant={STEP_VARIANT[s.status]}>{STEP_LABEL[s.status]}</Badge>
        </li>
      ))}
    </ul>
  );
}

export function RunPanel({ agentId, defaultTask, runs, timezone, disabled, configured }: {
  agentId: string; defaultTask: string; runs: RunRow[]; timezone: string; disabled: boolean; configured: boolean;
}) {
  const t = useT();
  const router = useRouter();
  const [prompt, setPrompt] = useState(defaultTask);
  const [result, setResult] = useState<{ output: string; steps: Step[]; status: string; error?: string } | null>(null);
  const [pending, start] = useTransition();
  const run = () => start(async () => {
    setResult(null);
    const r = await runAgent(agentId, prompt);
    if (!r.ok) { toast.error(r.error.message); return; }
    setResult(r.data);
    router.refresh();
  });
  return (
    <div className="grid gap-4">
      <Card>
        <CardHeader>
          <CardTitle>Задание</CardTitle>
          <CardDescription>Напишите, что сделать, как сотруднику. Агент сам найдёт клиентов и данные.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-3">
          {!configured ? <Alert variant="warning">{t("Встроенные агенты не подключены: на сервере не задан ANTHROPIC_API_KEY")}</Alert> : null}
          <Textarea value={prompt} onChange={(e) => setPrompt(e.target.value)} rows={4} maxLength={4000}
            placeholder={t("Например: найди клиентов, у которых абонемент заканчивается на этой неделе, и предложи им продление")} />
          <div className="flex justify-end">
            <Button onClick={run} disabled={pending || disabled || !configured || !prompt.trim()}><Play /> {pending ? "Агент работает…" : "Запустить"}</Button>
          </div>
          {pending ? <p className="text-sm text-muted-foreground">{t("Это может занять до пары минут: агент читает данные и выполняет шаги по очереди.")}</p> : null}
          {result ? (
            <div className="grid gap-2 rounded-2xl bg-field p-4">
              {result.status === "failed" ? <Alert variant="danger">{t(result.error ?? "Не удалось выполнить задание")}</Alert> : null}
              {result.output ? <p className="whitespace-pre-wrap text-sm">{result.output}</p> : null}
              <Steps steps={result.steps} />
            </div>
          ) : null}
        </CardContent>
      </Card>

      {runs.length ? (
        <Card>
          <CardHeader><CardTitle>Последние запуски</CardTitle></CardHeader>
          <CardContent className="grid gap-3">
            {runs.map((r) => (
              <details key={r.id} className="group rounded-2xl bg-field px-4 py-3">
                <summary className="flex cursor-pointer list-none flex-wrap items-center gap-2 text-sm">
                  <span className="font-medium">{dateTime(r.created_at, timezone)}</span>
                  <Badge variant={r.status === "done" ? "success" : r.status === "failed" ? "danger" : "info"}>
                    {r.status === "done" ? "Готово" : r.status === "failed" ? "Ошибка" : "Выполняется"}
                  </Badge>
                  {r.source === "schedule" ? <Badge variant="outline">По расписанию</Badge> : null}
                  <span className="min-w-0 flex-1 truncate text-muted-foreground">{r.prompt}</span>
                </summary>
                <div className="mt-3 grid gap-2">
                  {r.error ? <p className="text-sm text-destructive">{t(r.error)}</p> : null}
                  {r.output ? <p className="whitespace-pre-wrap text-sm">{r.output}</p> : null}
                  <Steps steps={r.steps} />
                </div>
              </details>
            ))}
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}
