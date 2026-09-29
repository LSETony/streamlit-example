import { ArrowDownRight, ArrowUpRight, Minus } from "lucide-react";
import { cn } from "@/lib/utils";

/** Изменение к прошлому периоду: знак, стрелка и цвет по смыслу (рост оттока — плохо) */
export function Delta({ current, previous, goodWhenUp, format, label, points }: {
  current: number; previous: number; goodWhenUp: boolean; format?: (v: number) => string; label?: string; points?: boolean;
}) {
  const diff = current - previous;
  if (diff === 0) {
    return <span className="inline-flex items-center gap-1 text-xs text-muted-foreground"><Minus className="size-3.5" /> без изменений{label ? ` ${label}` : ""}</span>;
  }
  const up = diff > 0;
  const good = up === goodWhenUp;
  const pctValue = previous !== 0 ? Math.abs(Math.round((diff / previous) * 100)) : null;
  const pct = pctValue !== null && !points ? ` (${pctValue === 0 ? "<1" : `${up ? "+" : "−"}${pctValue}`}%)` : "";
  const abs = points ? `${(Math.abs(Math.round(diff * 10) / 10)).toLocaleString("ru-RU")} п.п.` : format ? format(Math.abs(diff)) : Math.abs(diff).toLocaleString("ru-RU");
  const Icon = up ? ArrowUpRight : ArrowDownRight;
  return (
    <span className={cn("inline-flex items-center gap-1 text-xs font-medium", good ? "text-success" : "text-destructive")}>
      <Icon className="size-3.5" aria-hidden />
      <span>{up ? "+" : "−"}{abs}{pct}</span>
      {label ? <span className="font-normal text-muted-foreground">{label}</span> : null}
      <span className="sr-only">{good ? "(хорошо)" : "(плохо)"}</span>
    </span>
  );
}
