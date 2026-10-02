"use client";
import * as React from "react";
import { cn } from "@/lib/utils";
import { useTx } from "@/lib/i18n/client";

export function Table({ className, ...props }: React.ComponentProps<"table">) {
  return (
    <div className="w-full overflow-x-auto">
      <table className={cn("w-full caption-bottom text-sm", className)} {...props} />
    </div>
  );
}
export function THead({ className, ...props }: React.ComponentProps<"thead">) {
  return <thead className={cn("[&_tr]:border-b [&_tr]:border-separator", className)} {...props} />;
}
export function TBody({ className, ...props }: React.ComponentProps<"tbody">) {
  return <tbody className={cn("[&_tr:last-child]:border-0", className)} {...props} />;
}
export function TR({ className, ...props }: React.ComponentProps<"tr">) {
  return <tr className={cn("border-b border-separator/70 transition-colors", className)} {...props} />;
}
export function TH({ className, children, ...props }: React.ComponentProps<"th">) {
  const tx = useTx();
  return <th className={cn("h-10 px-4 text-left align-middle text-[13px] font-normal text-muted-foreground whitespace-nowrap", className)} {...props}>{tx(children)}</th>;
}
export function TD({ className, ...props }: React.ComponentProps<"td">) {
  return <td className={cn("px-4 py-3 align-middle", className)} {...props} />;
}
