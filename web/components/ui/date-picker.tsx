"use client";
import * as React from "react";
import { Popover } from "radix-ui";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import { cn } from "@/lib/utils";

/*
  Календарь в стиле iOS вместо браузерного input[type=date] (тот показывает формат ОС, например 09/01/2026).
  Даты — строки YYYY-MM-DD без часового пояса: все вычисления в UTC, чтобы день не «съезжал».
*/

const MONTHS = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];
const MONTHS_GEN_SHORT = ["янв.", "февр.", "мар.", "апр.", "мая", "июн.", "июл.", "авг.", "сент.", "окт.", "нояб.", "дек."];
const WEEKDAYS = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

const pad = (n: number) => String(n).padStart(2, "0");
const iso = (y: number, m: number, d: number) => `${y}-${pad(m + 1)}-${pad(d)}`;
const parts = (s: string) => {
  const [y, m, d] = s.split("-").map(Number);
  return { y, m: m - 1, d };
};
const todayIso = () => {
  const n = new Date();
  return iso(n.getFullYear(), n.getMonth(), n.getDate());
};

/** «1 сент. 2026» */
export function formatDay(s: string, withYear = true): string {
  if (!s) return "";
  const { y, m, d } = parts(s);
  return withYear ? `${d} ${MONTHS_GEN_SHORT[m]} ${y}` : `${d} ${MONTHS_GEN_SHORT[m]}`;
}

/** «1 – 29 сент. 2026», «28 сент. – 4 окт. 2026», «30 дек. 2025 – 5 янв. 2026» */
export function formatRange(from: string, to: string): string {
  if (!from) return "";
  if (!to || from === to) return formatDay(from);
  const a = parts(from);
  const b = parts(to);
  if (a.y !== b.y) return `${formatDay(from)} – ${formatDay(to)}`;
  if (a.m !== b.m) return `${formatDay(from, false)} – ${formatDay(to)}`;
  return `${a.d} – ${formatDay(to)}`;
}

function Calendar({ selected, rangeEnd, min, max, onPick, onToday, onClear }: {
  selected: string; rangeEnd?: string; min?: string; max?: string;
  onPick: (d: string) => void; onToday?: () => void; onClear?: () => void;
}) {
  const today = todayIso();
  const start = parts(selected || (max && max < today ? max : today));
  const [view, setView] = React.useState({ y: start.y, m: start.m });
  const [mode, setMode] = React.useState<"days" | "months">("days");
  const [hover, setHover] = React.useState<string | null>(null);

  const first = new Date(Date.UTC(view.y, view.m, 1));
  const offset = (first.getUTCDay() + 6) % 7; // понедельник — первый день недели
  const days = new Date(Date.UTC(view.y, view.m + 1, 0)).getUTCDate();
  const cells: (string | null)[] = [...Array(offset).fill(null), ...Array.from({ length: days }, (_, i) => iso(view.y, view.m, i + 1))];
  while (cells.length % 7) cells.push(null);

  const shift = (delta: number) => setView((v) => {
    const t = new Date(Date.UTC(v.y, v.m + delta, 1));
    return { y: t.getUTCFullYear(), m: t.getUTCMonth() };
  });
  const out = (d: string) => (min && d < min) || (max && d > max);

  // диапазон: выбранное начало и конец (или день под курсором, пока конец не выбран)
  const end = rangeEnd !== undefined ? (rangeEnd || hover || "") : "";
  const lo = end && end < selected ? end : selected;
  const hi = end && end < selected ? selected : end;
  const inRange = (d: string) => rangeEnd !== undefined && lo && hi && d > lo && d < hi;

  const years = Array.from({ length: 100 }, (_, i) => new Date().getFullYear() + 5 - i);

  return (
    <div className="w-[308px] select-none">
      <div className="mb-2 flex items-center justify-between pl-2">
        <button type="button" onClick={() => setMode((m) => (m === "days" ? "months" : "days"))}
          className="flex cursor-pointer items-center gap-1 rounded-lg px-1 py-1 text-[17px] font-semibold active:opacity-60">
          {MONTHS[view.m]} {view.y}
          <ChevronRight className={cn("size-[18px] text-tint-text transition-transform", mode === "months" && "rotate-90")} strokeWidth={2.5} />
        </button>
        {mode === "days" ? (
          <div className="flex">
            <button type="button" onClick={() => shift(-1)} aria-label="Предыдущий месяц"
              className="grid size-9 cursor-pointer place-items-center rounded-full text-tint-text hover:bg-field active:opacity-60">
              <ChevronLeft className="size-5" strokeWidth={2.5} />
            </button>
            <button type="button" onClick={() => shift(1)} aria-label="Следующий месяц"
              className="grid size-9 cursor-pointer place-items-center rounded-full text-tint-text hover:bg-field active:opacity-60">
              <ChevronRight className="size-5" strokeWidth={2.5} />
            </button>
          </div>
        ) : null}
      </div>

      {mode === "months" ? (
        <div className="grid grid-cols-[1fr_88px] gap-2">
          <div className="grid grid-cols-3 gap-1.5">
            {MONTHS.map((name, i) => (
              <button key={name} type="button" onClick={() => { setView((v) => ({ ...v, m: i })); setMode("days"); }}
                className={cn("h-10 cursor-pointer rounded-xl text-[13px] font-medium transition-colors",
                  i === view.m ? "bg-tint text-white" : "bg-field hover:bg-field-hover")}>
                {name.slice(0, 3)}
              </button>
            ))}
          </div>
          <div className="h-[172px] overflow-y-auto rounded-xl bg-field p-1 [scrollbar-width:thin]">
            {years.map((y) => (
              <button key={y} type="button" ref={y === view.y ? (el) => el?.scrollIntoView({ block: "center" }) : undefined}
                onClick={() => setView((v) => ({ ...v, y }))}
                className={cn("block h-8 w-full cursor-pointer rounded-lg text-[15px] tabular", y === view.y ? "bg-tint font-semibold text-white" : "hover:bg-field-hover")}>
                {y}
              </button>
            ))}
          </div>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-7 pb-1">
            {WEEKDAYS.map((w, i) => (
              <span key={w} className={cn("text-center text-[12px] font-semibold uppercase", i > 4 ? "text-label-3" : "text-muted-foreground")}>{w}</span>
            ))}
          </div>
          <div className="grid grid-cols-7 gap-y-0.5" onMouseLeave={() => setHover(null)}>
            {cells.map((d, i) => {
              if (!d) return <span key={`e${i}`} />;
              const disabled = out(d);
              const isSel = d === selected || (rangeEnd !== undefined && d === end && !!end);
              const isToday = d === today;
              const band = inRange(d);
              const isLo = rangeEnd !== undefined && hi && d === lo && lo !== hi;
              const isHi = rangeEnd !== undefined && hi && d === hi && lo !== hi;
              return (
                <div key={d} className={cn("relative flex h-10 items-center justify-center",
                  band && "bg-tint-soft", isLo && "bg-[linear-gradient(90deg,transparent_50%,var(--tint-soft)_50%)]",
                  isHi && "bg-[linear-gradient(90deg,var(--tint-soft)_50%,transparent_50%)]")}>
                  <button type="button" disabled={!!disabled} onClick={() => onPick(d)} onMouseEnter={() => setHover(d)}
                    aria-pressed={isSel} aria-label={formatDay(d)}
                    className={cn("relative grid size-10 cursor-pointer place-items-center rounded-full text-[17px] tabular transition-colors",
                      isSel ? "bg-tint font-semibold text-white" : isToday ? "font-semibold text-tint-text hover:bg-field" : "hover:bg-field",
                      disabled && "cursor-default opacity-30 hover:bg-transparent")}>
                    {Number(d.slice(8))}
                  </button>
                </div>
              );
            })}
          </div>
        </>
      )}

      {onToday || onClear ? (
        <div className="mt-2 flex items-center justify-between border-t border-separator/70 px-1 pt-2">
          {onToday ? (
            <button type="button" onClick={onToday} disabled={!!out(today)}
              className="cursor-pointer rounded-lg px-2 py-1.5 text-[15px] font-medium text-tint-text active:opacity-60 disabled:opacity-30">Сегодня</button>
          ) : <span />}
          {onClear ? (
            <button type="button" onClick={onClear} className="cursor-pointer rounded-lg px-2 py-1.5 text-[15px] text-destructive active:opacity-60">Очистить</button>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

const triggerClass =
  "inline-flex h-11 min-w-0 cursor-pointer items-center gap-2.5 rounded-xl bg-field px-4 text-left text-base transition-colors hover:bg-field-hover " +
  "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 data-[state=open]:bg-tint-soft";

function Panel({ children }: { children: React.ReactNode }) {
  return (
    <Popover.Portal>
      <Popover.Content align="start" sideOffset={8} collisionPadding={12}
        className="z-[60] rounded-[22px] bg-popover p-3 shadow-pop outline-none dark:shadow-[0_0_0_0.5px_rgb(255_255_255/0.08),var(--elev-pop)] data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95">
        {children}
      </Popover.Content>
    </Popover.Portal>
  );
}

/**
 * Выбор одной даты. Управляемый (value/onChange) или для форм (name + defaultValue — значение уходит скрытым полем).
 */
export function DatePicker({ value, defaultValue, onChange, name, min, max, placeholder = "Выберите дату", clearable, required, disabled, className, "aria-label": ariaLabel }: {
  value?: string; defaultValue?: string; onChange?: (v: string) => void; name?: string; min?: string; max?: string;
  placeholder?: string; clearable?: boolean; required?: boolean; disabled?: boolean; className?: string; "aria-label"?: string;
}) {
  const [inner, setInner] = React.useState(defaultValue ?? "");
  const current = value ?? inner;
  const [open, setOpen] = React.useState(false);
  const set = (v: string) => {
    if (value === undefined) setInner(v);
    onChange?.(v);
    setOpen(false);
  };
  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger disabled={disabled} aria-label={ariaLabel} className={cn(triggerClass, "w-full", className)}>
        <CalendarDays className="size-[18px] shrink-0 text-tint-text" />
        <span className={cn("truncate tabular", !current && "text-muted-foreground")}>{current ? formatDay(current) : placeholder}</span>
      </Popover.Trigger>
      {name ? <input type="hidden" name={name} value={current} required={required} /> : null}
      <Panel>
        <Calendar selected={current} min={min} max={max} onPick={set}
          onToday={() => set(todayIso())} onClear={clearable ? () => set("") : undefined} />
      </Panel>
    </Popover.Root>
  );
}

/** Период одним календарём: первое касание — начало, второе — конец (если раньше начала — меняются местами) */
export function DateRangePicker({ from, to, onChange, min, max, className, "aria-label": ariaLabel }: {
  from: string; to: string; onChange: (from: string, to: string) => void; min?: string; max?: string; className?: string; "aria-label"?: string;
}) {
  const [open, setOpen] = React.useState(false);
  const [draft, setDraft] = React.useState<{ from: string; to: string } | null>(null);
  const cur = draft ?? { from, to };
  const pick = (d: string) => {
    if (!draft || draft.to) {
      setDraft({ from: d, to: "" });
      return;
    }
    const [a, b] = d < draft.from ? [d, draft.from] : [draft.from, d];
    setDraft(null);
    setOpen(false);
    onChange(a, b);
  };
  return (
    <Popover.Root open={open} onOpenChange={(v) => { setOpen(v); if (!v) setDraft(null); }}>
      <Popover.Trigger aria-label={ariaLabel ?? "Период"} className={cn(triggerClass, className)}>
        <CalendarDays className="size-[18px] shrink-0 text-tint-text" />
        <span className="truncate tabular">{formatRange(from, to)}</span>
      </Popover.Trigger>
      <Panel>
        <p className="mb-2 px-2 text-[13px] text-muted-foreground">
          {draft && !draft.to ? "Выберите последний день" : "Выберите первый день периода"}
        </p>
        <Calendar selected={cur.from} rangeEnd={draft ? draft.to : cur.to} min={min} max={max} onPick={pick}
          onToday={() => { const t = todayIso(); setDraft(null); setOpen(false); onChange(t, t); }} />
      </Panel>
    </Popover.Root>
  );
}
