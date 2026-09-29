import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva("inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-xs leading-none font-medium whitespace-nowrap", {
  variants: {
    variant: {
      default: "bg-muted text-foreground",
      success: "bg-success/12 text-success",
      warning: "bg-warning/15 text-warning-foreground",
      danger: "bg-destructive/12 text-destructive",
      info: "bg-info/12 text-info",
      brand: "bg-brand-soft text-brand-ink",
      solid: "bg-foreground text-background",
      outline: "border border-border text-muted-foreground",
    },
  },
  defaultVariants: { variant: "default" },
});

export function Badge({ className, variant, ...props }: React.ComponentProps<"span"> & VariantProps<typeof badgeVariants>) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}
