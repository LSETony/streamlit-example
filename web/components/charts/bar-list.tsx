/** Горизонтальные полосы одной серии: подпись слева, значение у конца полосы */
export function BarList({ items }: { items: { label: string; value: number }[] }) {
  const max = Math.max(1, ...items.map((i) => i.value));
  return (
    <ul className="grid gap-2.5">
      {items.map((i) => (
        <li key={i.label} className="grid grid-cols-[minmax(90px,140px)_1fr] items-center gap-3 text-sm">
          <span className="truncate text-muted-foreground" title={i.label}>{i.label}</span>
          <span className="flex items-center gap-2">
            <span className="h-3 rounded-r-[4px]" style={{ width: `${(i.value / max) * 85}%`, minWidth: 4, background: "var(--chart-1)" }} />
            <span className="font-medium tabular">{i.value}</span>
          </span>
        </li>
      ))}
    </ul>
  );
}
