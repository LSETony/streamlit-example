import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva("inline-flex items-center gap-1 rounded-full px-2 py-[3px] text-[12px] leading-4 font-semibold whitespace-nowrap", {
  variants: {
    variant: {
      default: "bg-muted text-foreground",
      success: "bg-success-fill/15 text-success",
      warning: "bg-warning/15 text-warning-foreground",
      danger: "bg-destructive/12 text-destructive",
      info: "bg-tint-soft text-tint-text",
      brand: "bg-tint-soft text-tint-text",
      solid: "bg-foreground text-background",
      outline: "bg-field text-muted-foreground",
    },
  },
  defaultVariants: { variant: "default" },
});

export function Badge({ className, variant, ...props }: React.ComponentProps<"span"> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}
