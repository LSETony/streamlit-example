"use client";
import * as React from "react";
import { cn } from "@/lib/utils";
import { useTx } from "@/lib/i18n/client";

export function Input({ className, type, placeholder, "aria-label": ariaLabel, ...props }: React.ComponentProps<"input">) {
  const tx = useTx();
  return (
    <input
      type={type}
      placeholder={tx(placeholder) as string | undefined}
      aria-label={tx(ariaLabel) as string | undefined}
      className={cn(
        "flex h-11 w-full rounded-xl border border-transparent bg-field px-4 py-2 text-base placeholder:text-muted-foreground " +
          "transition-[border-color,box-shadow] focus-visible:outline-none hover:bg-field-hover focus-visible:bg-card focus-visible:ring-2 focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 " +
          "aria-[invalid=true]:border-destructive file:border-0 file:bg-transparent file:text-sm file:font-medium",
        className,
      )}
      {...props}
    />
  );
}

export function Textarea({ className, placeholder, ...props }: React.ComponentProps<"textarea">) {
  const tx = useTx();
  return (
    <textarea
      placeholder={tx(placeholder) as string | undefined}
      className={cn(
        "flex min-h-24 w-full rounded-xl border border-transparent bg-field px-4 py-3 text-base placeholder:text-muted-foreground " +
          "transition-[border-color,box-shadow] focus-visible:outline-none hover:bg-field-hover focus-visible:bg-card focus-visible:ring-2 focus-visible:ring-ring/50 disabled:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

// Выпадающий список — меню в стиле iOS (клиентский компонент, API как у <select>)
export { NativeSelect } from "./select";
import { NativeSelect } from "./select";

export function Label({ className, children, ...props }: React.ComponentProps<"label">) {
  const tx = useTx();
  return <label className={cn("pl-1 text-[13px] leading-none text-muted-foreground", className)} {...props}>{tx(children)}</label>;
}

export function Field({ label, hint, error, children, className }: {
  label: string; hint?: React.ReactNode; error?: string | null; children: React.ReactNode; className?: string;
}) {
  const tx = useTx();
  return (
    <div className={cn("grid gap-1.5", className)}>
      <Label>{label}</Label>
      {children}
      {error ? <p className="text-xs text-destructive">{tx(error)}</p> : hint ? <p className="text-xs text-muted-foreground">{tx(hint)}</p> : null}
    </div>
  );
}

/** Отметка в стиле iOS: круг, при выборе — залит цветом акцента с белой галочкой (нативный input — для форм и required) */
export function Checkbox({ label, className, ...props }: React.ComponentProps<"input"> & { label: React.ReactNode }) {
  const tx = useTx();
  return (
    <label className={cn("flex cursor-pointer items-start gap-3 text-[15px] leading-5", className)}>
      <input type="checkbox" className="ios-check mt-[-1px] shrink-0" {...props} />
      <span>{tx(label)}</span>
    </label>
  );
}

/** Выбор времени в 24-часовом формате (нативный input[type=time] в части браузеров показывает AM/PM) */
export function TimeSelect({ value, defaultValue, onChange, name, className, step = 30, "aria-label": ariaLabel }: {
  value?: string; defaultValue?: string; onChange?: (v: string) => void; name?: string; className?: string; step?: number; "aria-label"?: string;
}) {
  const options: string[] = [];
  for (let m = 0; m < 24 * 60; m += step) options.push(`${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`);
  const known = value ?? defaultValue;
  if (known && !options.includes(known)) options.push(known);
  options.sort();
  return (
    <NativeSelect value={value} defaultValue={defaultValue} name={name} onChange={onChange ? (e) => onChange(e.target.value) : undefined}
      className={cn("w-[104px] px-3.5 tabular", className)} aria-label={ariaLabel}>
      {options.map((o) => <option key={o} value={o}>{o === "24:00" ? "24:00" : o}</option>)}
    </NativeSelect>
  );
}
