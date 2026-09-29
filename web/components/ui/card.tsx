import * as React from "react";
import { cn } from "@/lib/utils";

export function Card({ className, variant = "glass", ...props }: React.ComponentProps<"div"> & { variant?: "glass" | "hero" }) {
  return <div className={cn("rounded-[28px] text-card-foreground", variant === "hero" ? "hero" : "glass", className)} {...props} />;
}

export function CardHeader({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex flex-col gap-1 p-6 pb-3", className)} {...props} />;
}

export function CardTitle({ className, ...props }: React.ComponentProps<"h3">) {
  return <h3 className={cn("text-base font-semibold tracking-tight", className)} {...props} />;
}

export function CardDescription({ className, ...props }: React.ComponentProps<"p">) {
  return <p className={cn("text-sm text-muted-foreground", className)} {...props} />;
}

export function CardContent({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("p-6 pt-0", className)} {...props} />;
}
