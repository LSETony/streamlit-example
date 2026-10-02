"use client";
import * as React from "react";
import { Slot } from "radix-ui";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";
import { useTx } from "@/lib/i18n/client";

/**
 * Кнопки в стиле iOS: капсула, высота 44 pt (минимальная зона касания), нажатие — лёгкое сжатие.
 * default — заливка цветом акцента (tint), secondary — «tinted», outline — «серая» с подписью цветом акцента, ghost/link — «plain».
 */
const buttonVariants = cva(
  "inline-flex select-none items-center justify-center gap-2 whitespace-nowrap rounded-full text-[15px] font-semibold " +
    "transition-[background-color,opacity,transform,filter] duration-150 active:scale-[0.97] active:opacity-80 " +
    "focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25 " +
    "disabled:pointer-events-none disabled:opacity-40 [&_svg]:pointer-events-none [&_svg]:size-[18px] [&_svg]:shrink-0 cursor-pointer",
  {
    variants: {
      variant: {
        default: "bg-tint text-white hover:brightness-110",
        brand: "bg-tint text-white hover:brightness-110",
        destructive: "bg-destructive text-white hover:brightness-110",
        outline: "bg-field text-tint-text hover:bg-field-hover",
        secondary: "bg-tint-soft text-tint-text hover:brightness-95 dark:hover:brightness-125",
        ghost: "text-tint-text hover:bg-field",
        link: "rounded-md text-tint-text hover:opacity-70",
      },
      size: {
        default: "h-11 px-5",
        sm: "h-9 px-4 text-[13px] [&_svg]:size-4",
        lg: "h-[50px] px-7 text-[17px]",
        xl: "h-16 px-9 text-lg",
        icon: "size-11",
        "icon-sm": "size-9 [&_svg]:size-4",
      },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

export function Button({ className, variant, size, asChild = false, ...props }: ButtonProps) {
  const tx = useTx();
  const Comp = asChild ? Slot.Root : "button";
  const { children, title, "aria-label": ariaLabel, ...rest } = props;
  return (
    <Comp className={cn(buttonVariants({ variant, size, className }))} title={tx(title) as string | undefined} aria-label={tx(ariaLabel) as string | undefined} {...rest}>
      {tx(children)}
    </Comp>
  );
}

export { buttonVariants };
