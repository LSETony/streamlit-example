"use client";
import { ArrowDownRight, ArrowUpRight, Minus } from "lucide-react";
import { cn } from "@/lib/utils";
import { useT } from "@/lib/i18n/client";
import { money as formatMoney } from "@/lib/format";

/** Изменение к прошлому периоду: знак, стрелка и цвет по смыслу (рост оттока — плохо) */
export function Delta({ current, previous, goodWhenUp, currency, label, points }: {
  current: number; previous: number; goodWhenUp: boolean; currency?: string; label?: string; points?: boolean;
}) {
  const t = useT();
  const diff = current - previous;
  if (diff === 0) {
    return <span className="inline-flex items-center gap-1 text-xs text-muted-foreground"><Minus className="size-3.5" /> {t("без изменений")}{label ? ` ${label}` : ""}</span>;
  }
  const up = diff > 0;
  const good = up === goodWhenUp;
  const pctValue = previous !== 0 ? Math.abs(Math.round((diff / previous) * 100)) : null;
  const pct = pctValue !== null && !points ? ` (${pctValue === 0 ? "<1" : `${up ? "+" : "−"}${pctValue}`}%)` : "";
  const abs = points ? `${(Math.abs(Math.round(diff * 10) / 10)).toLocaleString(t.intl)} ${t("п.п.")}` : currency ? formatMoney(Math.abs(diff), currency) : Math.abs(diff).toLocaleString(t.intl);
  const Icon = up ? ArrowUpRight : ArrowDownRight;
  return (
    <span className={cn("inline-flex items-center gap-1 text-xs font-medium", good ? "text-success" : "text-destructive")}>
      <Icon className="size-3.5" aria-hidden />
      <span>{up ? "+" : "−"}{abs}{pct}</span>
      {label ? <span className="font-normal text-muted-foreground">{label}</span> : null}
      <span className="sr-only">{good ? t("(хорошо)") : t("(плохо)")}</span>
    </span>
  );
}
