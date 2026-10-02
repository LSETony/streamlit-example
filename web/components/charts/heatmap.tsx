"use client";
import { useState } from "react";
import { useT } from "@/lib/i18n/client";

const DAYS = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

/** Тепловая карта «день недели × час»: одна последовательная шкала (светлее → темнее), подсказка на ячейке */
export function Heatmap({ cells, hours }: { cells: { dow: number; hour: number; avg: number }[]; hours: [number, number] }) {
  const t = useT();
  const [tip, setTip] = useState<{ dow: number; hour: number; avg: number } | null>(null);
  const map = new Map(cells.map((c) => [`${c.dow}-${c.hour}`, c.avg]));
  const max = Math.max(0.1, ...cells.map((c) => c.avg));
  const hourList = Array.from({ length: hours[1] - hours[0] + 1 }, (_, i) => hours[0] + i);
  const steps = 5;
  // непрерывная последовательная шкала одного тона: доля от максимума → насыщенность
  const fill = (v: number) => (v <= 0 ? "var(--muted)" : `color-mix(in oklab, var(--chart-1) ${Math.round(8 + (v / max) * 84)}%, var(--card))`);

  return (
    <div className="grid gap-3">
      <div className="overflow-x-auto">
        <div className="grid min-w-[520px] gap-[2px]" style={{ gridTemplateColumns: `28px repeat(${hourList.length}, minmax(0, 1fr))` }}>
          <span />
          {hourList.map((h) => (
            <span key={h} className="pb-1 text-center text-[10px] text-muted-foreground tabular">{h % 2 === 0 ? h : ""}</span>
          ))}
          {DAYS.map((d, di) => (
            <Row key={d} label={t(d)}>
              {hourList.map((h) => {
                const v = map.get(`${di + 1}-${h}`) ?? 0;
                return (
                  <button
                    key={h}
                    type="button"
                    className="aspect-square min-h-4 rounded-[3px] outline-offset-1 focus-visible:outline-2 focus-visible:outline-ring"
                    style={{ background: fill(v) }}
                    onMouseEnter={() => setTip({ dow: di + 1, hour: h, avg: v })}
                    onFocus={() => setTip({ dow: di + 1, hour: h, avg: v })}
                    onMouseLeave={() => setTip(null)}
                    aria-label={t("{day}, {hour}:00 — в среднем {n} чел.", { day: t(d), hour: h, n: v.toLocaleString(t.intl) })}
                  />
                );
              })}
            </Row>
          ))}
        </div>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
        <span className="min-h-4" aria-live="polite">
          {tip ? <>{t(DAYS[tip.dow - 1])}, {tip.hour}:00–{tip.hour + 1}:00 · {t("в среднем")} <b className="text-foreground tabular">{tip.avg.toLocaleString(t.intl)}</b> {t("чел.")}</> : t("Наведите на ячейку, чтобы увидеть значение")}
        </span>
        <span className="flex items-center gap-1">
          {t("меньше")}
          {Array.from({ length: steps + 1 }, (_, l) => (
            <span key={l} className="size-3 rounded-[3px]" style={{ background: fill((l / steps) * max) }} />
          ))}
          {t("больше")}
        </span>
      </div>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <>
      <span className="flex items-center text-xs text-muted-foreground">{label}</span>
      {children}
    </>
  );
}
