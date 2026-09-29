"use client";
import * as React from "react";
import { Switch as S } from "radix-ui";
import { cn } from "@/lib/utils";

export function Switch({ className, ...props }: React.ComponentProps<typeof S.Root>) {
  return (
    <S.Root
      className={cn(
        "peer inline-flex h-[31px] w-[51px] shrink-0 cursor-pointer items-center rounded-full p-[2px] transition-colors duration-200 " +
          "focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-foreground/10 disabled:cursor-not-allowed disabled:opacity-50 " +
          "data-[state=checked]:bg-success-fill data-[state=unchecked]:bg-field-hover",
        className,
      )}
      {...props}
    >
      <S.Thumb className="pointer-events-none block size-[27px] rounded-full bg-white shadow-[0_3px_8px_rgb(0_0_0/0.15),0_3px_1px_rgb(0_0_0/0.06)] ring-0 transition-transform duration-200 data-[state=checked]:translate-x-5 data-[state=unchecked]:translate-x-0" />
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
