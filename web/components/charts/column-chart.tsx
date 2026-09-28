"use client";
import { useState } from "react";

/** Столбчатая диаграмма одной серии: ≤24px столбцы, скругление 4px сверху, общая базовая линия, подсказка при наведении */
export function ColumnChart({ data, unit = "", highlightLast, height = 140 }: {
  data: { key: string; label: string; value: number }[]; unit?: string; highlightLast?: boolean; height?: number;
}) {
  const formatValue = (v: number) => `${Math.round(v).toLocaleString("ru-RU")}${unit ? ` ${unit}` : ""}`;
  const labels = new Map(data.map((d) => [d.key, d.label]));
  const formatLabel = (key: string) => labels.get(key) ?? key;
  const [hover, setHover] = useState<number | null>(null);
  const max = Math.max(1, ...data.map((d) => d.value));
  const nice = niceMax(max);
  return (
    <div className="relative">
      <div className="relative flex items-end gap-1" style={{ height }}>
        {[0.5, 1].map((f) => (
          <div key={f} className="pointer-events-none absolute inset-x-0 border-t border-[var(--chart-grid)]" style={{ bottom: `${f * 100}%` }}>
            <span className="absolute -top-2 right-0 bg-card pl-1 text-[10px] leading-none text-muted-foreground tabular">{formatValue(nice * f)}</span>
          </div>
        ))}
        {data.map((d, i) => {
          const h = (d.value / nice) * 100;
          const accent = highlightLast && i === data.length - 1;
          return (
            <div
              key={d.key}
              className="relative flex h-full flex-1 cursor-default items-end justify-center"
              onMouseEnter={() => setHover(i)}
              onMouseLeave={() => setHover(null)}
            >
              <div
                className="w-full max-w-6 rounded-t-[4px] transition-opacity"
                style={{
                  height: `${Math.max(h, d.value > 0 ? 1.5 : 0)}%`,
                  background: "var(--chart-1)",
                  opacity: hover === null ? (accent || !highlightLast ? 1 : 0.35) : hover === i ? 1 : 0.35,
                }}
              />
              {hover === i ? (
                <div className="pointer-events-none absolute bottom-full z-10 mb-1 whitespace-nowrap rounded-lg border border-border bg-card px-2 py-1 text-xs shadow-md">
                  <span className="text-muted-foreground">{formatLabel(d.key)}</span> <b className="tabular">{formatValue(d.value)}</b>
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
      <div className="mt-1 flex gap-1 border-t border-border pt-1">
        {data.map((d) => (
          <span key={d.key} className="flex-1 text-center text-[10px] text-muted-foreground">{formatLabel(d.key)}</span>
        ))}
      </div>
      <table className="sr-only">
        <tbody>{data.map((d) => <tr key={d.key}><th>{formatLabel(d.key)}</th><td>{formatValue(d.value)}</td></tr>)}</tbody>
      </table>
    </div>
  );
}

function niceMax(v: number): number {
  const exp = Math.pow(10, Math.floor(Math.log10(v)));
  for (const m of [1, 2, 2.5, 5, 10]) if (v <= m * exp) return m * exp;
  return 10 * exp;
}
