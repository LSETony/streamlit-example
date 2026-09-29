"use client";
import * as React from "react";
import { Switch as S } from "radix-ui";
import { cn } from "@/lib/utils";

export function Switch({ className, ...props }: React.ComponentProps<typeof S.Root>) {
  return (
    <S.Root
      className={cn(
        "peer inline-flex h-6 w-10 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors " +
          "focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-foreground/10 disabled:cursor-not-allowed disabled:opacity-50 " +
          "data-[state=checked]:bg-info data-[state=unchecked]:bg-field-hover",
        className,
      )}
      {...props}
    >
      <S.Thumb className="pointer-events-none block size-5 rounded-full bg-card shadow-sm ring-0 transition-transform data-[state=checked]:translate-x-4 data-[state=unchecked]:translate-x-0" />
    </S.Root>
  );
}

/** Строка настройки: заголовок, пояснение, переключатель справа */
export function SwitchRow({ title, description, name, defaultChecked, checked, onCheckedChange, disabled }: {
  title: string; description?: string; name?: string; defaultChecked?: boolean; checked?: boolean;
  onCheckedChange?: (v: boolean) => void; disabled?: boolean;
}) {
  const id = React.useId();
  return (
    <div className="flex items-center justify-between gap-6 py-1">
      <label htmlFor={id} className="grid cursor-pointer gap-0.5">
        <span className="text-sm font-medium">{title}</span>
        {description ? <span className="text-xs text-muted-foreground">{description}</span> : null}
      </label>
      <Switch id={id} name={name} value="on" defaultChecked={defaultChecked} checked={checked} onCheckedChange={onCheckedChange} disabled={disabled} />
    </div>
  );
}
