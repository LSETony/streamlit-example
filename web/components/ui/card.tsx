"use client";
import * as React from "react";
import { cn } from "@/lib/utils";
import { useTx } from "@/lib/i18n/client";

/** Ячейка-секция как в iOS (inset grouped): непрозрачная, скругление 24 pt; hero — акцентная карточка цвета tint */
export function Card({ className, variant = "glass", ...props }: React.ComponentProps<"div"> & { variant?: "glass" | "hero" }) {
  return <div className={cn("relative rounded-[24px] text-card-foreground", variant === "hero" ? "hero glass-rim" : "glass-card", className)} {...props} />;
}

export function CardHeader({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex flex-col gap-1 px-5 pb-2 pt-5", className)} {...props} />;
}

export function CardTitle({ className, children, ...props }: React.ComponentProps<"h3">) {
  const tx = useTx();
  return <h3 className={cn("text-[17px] font-semibold leading-[22px] tracking-[-0.01em]", className)} {...props}>{tx(children)}</h3>;
}

export function CardDescription({ className, children, ...props }: React.ComponentProps<"p">) {
  const tx = useTx();
  return <p className={cn("text-[13px] leading-[18px] text-muted-foreground", className)} {...props}>{tx(children)}</p>;
}

export function CardContent({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("px-5 pb-5", className)} {...props} />;
}
