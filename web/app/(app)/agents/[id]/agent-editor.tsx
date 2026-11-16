"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { Bot, Plug, Trash2 } from "lucide-react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Field, Input, Textarea } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { SwitchRow } from "@/components/ui/switch";
import { Segmented, segmentClass } from "@/components/ui/tabs";
import { AGENT_TEMPLATES, AGENT_TOOLS, type ToolMode } from "@/lib/ai/tools";
import type { AgentRow } from "@/lib/ai/execute";
import { deleteAgent, saveAgent } from "@/app/actions/agents";
import { useT } from "@/lib/i18n/client";

const MODE_LABEL: Record<ToolMode, string> = { off: "Выкл.", approve: "С подтверждением", auto: "Сам" };

export function AgentEditor({ agent, readOnly }: { agent: AgentRow | null; readOnly: boolean }) {
  const t = useT();
  const router = useRouter();
  const isNew = !agent;
  const [kind, setKind] = useState<"builtin" | "external">(agent?.kind ?? "builtin");
  const [template, setTemplate] = useState(agent?.template ?? "retention");
  const tpl0 = AGENT_TEMPLATES.find((x) => x.id === template) ?? AGENT_TEMPLATES[0];
  const [name, setName] = useState(agent?.name ?? t(tpl0.label));
  const [instructions, setInstructions] = useState(agent?.instructions ?? t(tpl0.instructions));
  const [task, setTask] = useState(agent?.task ?? t(tpl0.task));
  const [tools, setTools] = useState<Record<string, ToolMode>>((agent?.tools as Record<string, ToolMode>) ?? tpl0.tools);
  const [schedule, setSchedule] = useState<"off" | "daily">(agent?.schedule ?? "off");
  const [enabled, setEnabled] = useState(agent?.enabled ?? true);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  const pickTemplate = (id: string) => {
    const tpl = AGENT_TEMPLATES.find((x) => x.id === id)!;
    setTemplate(id);
    setName(t(tpl.label));
    setInstructions(t(tpl.instructions));
    setTask(t(tpl.task));
    setTools(tpl.tools);
  };

  const save = () => start(async () => {
    setError(null);
    const r = await saveAgent({ id: agent?.id ?? null, name, kind, template, instructions, task, tools, schedule, enabled });
    if (!r.ok) return setError(r.error.message);
    toast.success(isNew ? "Агент создан" : "Сохранено");
    if (isNew) router.push(`/agents/${r.data}`); else router.refresh();
  });

  const remove = () => start(async () => {
    if (!confirm(t("Удалить агента? Ключи перестанут работать, история его действий тоже удалится."))) return;
    const r = await deleteAgent(agent!.id);
    if (!r.ok) { toast.error(r.error.message); return; }
    router.push("/agents");
  });

  const writeOn = AGENT_TOOLS.some((x) => x.kind === "write" && tools[x.name] === "auto");

  return (
    <div className="grid gap-4">
      {isNew ? (
        <Card>
          <CardHeader><CardTitle>Тип агента</CardTitle></CardHeader>
          <CardContent className="grid gap-3 sm:grid-cols-2">
            {([["builtin", Bot, "Встроенный", "Работает в core. на модели Claude. Запускается из кабинета или каждый день сам."],
               ["external", Plug, "Внешний", "Ваш агент (ChatGPT, Claude, n8n, свой код) подключается по API-ключу или через MCP."]] as const).map(([k, Icon, title, text]) => (
              <button key={k} type="button" onClick={() => setKind(k)} aria-pressed={kind === k}
                className="grid cursor-pointer gap-1 rounded-2xl border border-transparent bg-field p-4 text-left transition aria-pressed:border-tint aria-pressed:bg-tint-soft">
                <span className="flex items-center gap-2 font-semibold"><Icon className="size-4" /> {t(title)}</span>
                <span className="text-xs text-muted-foreground">{t(text)}</span>
              </button>
            ))}
          </CardContent>
          <CardContent className="grid gap-2 pt-0">
            <p className="text-sm font-medium">{t("Шаблон")}</p>
            <div className="grid gap-2 sm:grid-cols-2">
              {AGENT_TEMPLATES.map((x) => (
                <button key={x.id} type="button" onClick={() => pickTemplate(x.id)} aria-pressed={template === x.id}
                  className="grid cursor-pointer gap-0.5 rounded-2xl border border-transparent bg-field px-4 py-3 text-left transition aria-pressed:border-tint aria-pressed:bg-tint-soft">
                  <span className="text-sm font-semibold">{t(x.label)}</span>
                  <span className="text-xs text-muted-foreground">{t(x.description)}</span>
                </button>
              ))}
            </div>
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader>
          <CardTitle>Настройки</CardTitle>
          <CardDescription>Агент действует от имени того, кто последним сохранил настройки, и не может больше, чем этот сотрудник.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-4">
          <Field label="Название"><Input value={name} onChange={(e) => setName(e.target.value)} maxLength={80} /></Field>
          <Field label="Инструкции" hint="Роль, тон общения, что можно и нельзя обещать клиентам">
            <Textarea value={instructions} onChange={(e) => setInstructions(e.target.value)} rows={5} maxLength={8000} />
          </Field>
          {kind === "builtin" ? (
            <>
              <Field label="Задание по умолчанию" hint="Подставляется при запуске и выполняется каждый день, если включено расписание">
                <Textarea value={task} onChange={(e) => setTask(e.target.value)} rows={3} maxLength={4000} />
              </Field>
              <SwitchRow title="Запускать каждый день" description="Утром агент сам выполняет задание по умолчанию"
                checked={schedule === "daily"} onCheckedChange={(v) => setSchedule(v ? "daily" : "off")} />
            </>
          ) : null}
          <SwitchRow title="Агент включён" description="Выключенный агент не может ничего делать, ключи не работают"
            checked={enabled} onCheckedChange={setEnabled} />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Права</CardTitle>
          <CardDescription>«С подтверждением» — действие ждёт сотрудника в очереди. «Сам» — агент выполняет без вопросов.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-1">
          {AGENT_TOOLS.map((x) => {
            const mode = tools[x.name] ?? "off";
            const modes: ToolMode[] = x.kind === "read" ? ["off", "auto"] : ["off", "approve", "auto"];
            return (
              <div key={x.name} className="flex flex-wrap items-center justify-between gap-x-4 gap-y-2 border-b border-separator py-2.5 last:border-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">{t(x.label)}</span>
                  <Badge variant={x.kind === "read" ? "outline" : "info"}>{x.kind === "read" ? "Чтение" : "Действие"}</Badge>
                </div>
                <Segmented aria-label={t(x.label)} className="ml-auto">
                  {modes.map((m) => (
                    <button key={m} type="button" className={`${segmentClass} shrink-0`} aria-pressed={mode === m}
                      onClick={() => setTools((p) => ({ ...p, [x.name]: m }))}>{t(x.kind === "read" && m === "auto" ? "Вкл." : MODE_LABEL[m])}</button>
                  ))}
                </Segmented>
              </div>
            );
          })}
          {writeOn ? <Alert variant="warning" className="mt-2">{t("Часть действий агент выполняет сам, без подтверждения. Всё, что он сделал, видно в журнале действий агентов.")}</Alert> : null}
        </CardContent>
      </Card>

      {error ? <Alert variant="danger">{t(error)}</Alert> : null}
      <div className="flex flex-wrap justify-between gap-2">
        {!isNew ? <Button variant="ghost" onClick={remove} disabled={pending || readOnly}><Trash2 /> Удалить</Button> : <span />}
        <Button onClick={save} disabled={pending || readOnly}>{pending ? "Сохраняем…" : isNew ? "Создать агента" : "Сохранить"}</Button>
      </div>
    </div>
  );
}
