import * as React from "react";
import { cn } from "@/lib/utils";

export function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      className={cn(
        "flex h-10 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm placeholder:text-muted-foreground " +
          "transition-[border-color,box-shadow] focus-visible:outline-none focus-visible:border-foreground/40 focus-visible:ring-4 focus-visible:ring-foreground/8 disabled:cursor-not-allowed disabled:opacity-50 " +
          "aria-[invalid=true]:border-destructive file:border-0 file:bg-transparent file:text-sm file:font-medium",
        className,
      )}
      {...props}
    />
  );
}

export function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      className={cn(
        "flex min-h-20 w-full rounded-lg border border-input bg-card px-3 py-2 text-sm placeholder:text-muted-foreground " +
          "transition-[border-color,box-shadow] focus-visible:outline-none focus-visible:border-foreground/40 focus-visible:ring-4 focus-visible:ring-foreground/8 disabled:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

export function NativeSelect({ className, children, ...props }: React.ComponentProps<"select">) {
  return (
    <select
      className={cn(
        "flex h-10 w-full appearance-none rounded-lg border border-input bg-card bg-[length:16px] bg-[right_10px_center] bg-no-repeat px-3 pr-9 text-sm " +
          "focus-visible:outline-none focus-visible:border-foreground/40 focus-visible:ring-4 focus-visible:ring-foreground/8 disabled:opacity-50 " +
          "bg-[url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%23888' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E\")]",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
}

export function Label({ className, ...props }: React.ComponentProps<"label">) {
  return <label className={cn("text-[13px] font-medium leading-none text-foreground/80", className)} {...props} />;
}

export function Field({ label, hint, error, children, className }: {
  label: string; hint?: React.ReactNode; error?: string | null; children: React.ReactNode; className?: string;
}) {
  return (
    <div className={cn("grid gap-1.5", className)}>
      <Label>{label}</Label>
      {children}
      {error ? <p className="text-xs text-destructive">{error}</p> : hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

export function Checkbox({ label, className, ...props }: React.ComponentProps<"input"> & { label: React.ReactNode }) {
  return (
    <label className={cn("flex cursor-pointer items-start gap-2.5 text-sm", className)}>
      <input type="checkbox" className="mt-0.5 size-4 shrink-0 cursor-pointer accent-[var(--foreground)]" {...props} />
      <span>{label}</span>
    </label>
  );
}

/** Выбор времени в 24-часовом формате (нативный input[type=time] в части браузеров показывает AM/PM) */
export function TimeSelect({ value, onChange, className, step = 30, "aria-label": ariaLabel }: {
  value: string; onChange: (v: string) => void; className?: string; step?: number; "aria-label"?: string;
}) {
  const options: string[] = [];
  for (let m = 0; m < 24 * 60; m += step) options.push(`${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`);
  if (!options.includes(value)) options.push(value);
  options.sort();
  return (
    <NativeSelect value={value} onChange={(e) => onChange(e.target.value)} className={cn("w-[92px] tabular", className)} aria-label={ariaLabel}>
      {options.map((o) => <option key={o} value={o}>{o === "24:00" ? "24:00" : o}</option>)}
    </NativeSelect>
  );
}
