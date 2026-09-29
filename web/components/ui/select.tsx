"use client";
import * as React from "react";
import { Select as S } from "radix-ui";
import { Check, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

/*
  Выпадающий список в стиле меню iOS вместо системного <select> (у того вид зависит от браузера и ОС).
  API как у <select>: <option> внутри, value/defaultValue, onChange(e) с e.target.value, name для форм —
  поэтому все места платформы переключились без правок. Значение уходит в форму скрытым полем.
*/

// Radix не разрешает пустое значение у пункта — «Все …»/«Не указан» кодируем отдельным маркером
const EMPTY = "__empty__";
const enc = (v: string) => (v === "" ? EMPTY : v);
const dec = (v: string) => (v === EMPTY ? "" : v);

interface Opt { value: string; label: React.ReactNode; disabled?: boolean }

function readOptions(children: React.ReactNode): Opt[] {
  return React.Children.toArray(children).flatMap((c) => {
    if (!React.isValidElement<React.ComponentProps<"option">>(c) || c.type !== "option") return [];
    return [{ value: String(c.props.value ?? ""), label: c.props.children, disabled: c.props.disabled }];
  });
}

export function NativeSelect({ className, children, value, defaultValue, onChange, name, required, disabled, id, "aria-label": ariaLabel }: React.ComponentProps<"select">) {
  const options = readOptions(children);
  const [inner, setInner] = React.useState(String(defaultValue ?? options[0]?.value ?? ""));
  const current = value !== undefined ? String(value) : inner;
  const selected = options.find((o) => o.value === current);

  const handle = (v: string) => {
    const next = dec(v);
    if (value === undefined) setInner(next);
    // тот же вид события, что у <select>: вызывающий код читает e.target.value
    const target = { value: next, name: name ?? "" };
    onChange?.({ target, currentTarget: target } as unknown as React.ChangeEvent<HTMLSelectElement>);
  };

  return (
    <S.Root value={enc(current)} onValueChange={handle} disabled={disabled}>
      <S.Trigger id={id} aria-label={ariaLabel}
        className={cn(
          "flex h-11 w-full min-w-0 cursor-pointer items-center justify-between gap-2 rounded-xl bg-field px-4 text-left text-base transition-colors " +
            "hover:bg-field-hover focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 data-[state=open]:bg-tint-soft " +
            "disabled:cursor-not-allowed disabled:opacity-50",
          className,
        )}>
        <S.Value>
          <span className="truncate">{selected?.label ?? ""}</span>
        </S.Value>
        <S.Icon asChild>
          <ChevronsUpDown className="size-4 shrink-0 text-muted-foreground" />
        </S.Icon>
      </S.Trigger>
      {name ? <input type="hidden" name={name} value={current} required={required} /> : null}
      <S.Portal>
        <S.Content position="popper" sideOffset={6} collisionPadding={12}
          className={cn(
            "z-[60] max-h-[min(22rem,var(--radix-select-content-available-height))] min-w-[max(var(--radix-select-trigger-width),12rem)] overflow-hidden rounded-[18px] bg-popover shadow-pop",
            "dark:shadow-[0_0_0_0.5px_rgb(255_255_255/0.08),var(--elev-pop)] data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95",
          )}>
          <S.ScrollUpButton className="flex h-6 items-center justify-center text-muted-foreground">⌃</S.ScrollUpButton>
          <S.Viewport className="p-1.5">
            {options.map((o) => (
              <S.Item key={o.value} value={enc(o.value)} disabled={o.disabled}
                className={cn(
                  "relative flex h-11 cursor-pointer select-none items-center rounded-xl pl-10 pr-4 text-[17px] outline-none",
                  "data-[highlighted]:bg-field data-[disabled]:cursor-default data-[disabled]:opacity-40 data-[state=checked]:font-medium",
                )}>
                <S.ItemIndicator className="absolute left-3.5 flex items-center">
                  <Check className="size-[18px] text-tint-text" strokeWidth={2.75} />
                </S.ItemIndicator>
                <S.ItemText>{o.label}</S.ItemText>
              </S.Item>
            ))}
          </S.Viewport>
          <S.ScrollDownButton className="flex h-6 items-center justify-center text-muted-foreground">⌄</S.ScrollDownButton>
        </S.Content>
      </S.Portal>
    </S.Root>
  );
}
