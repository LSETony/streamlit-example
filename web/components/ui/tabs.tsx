"use client";
import * as React from "react";
import { Tabs as T } from "radix-ui";
import { cn } from "@/lib/utils";

export const Tabs = T.Root;

export function TabsList({ className, ...props }: React.ComponentProps<typeof T.List>) {
  return (
    <T.List
      className={cn("inline-flex h-11 max-w-full items-center gap-1 overflow-x-auto rounded-full bg-field p-1 text-muted-foreground", className)}
      {...props}
    />
  );
}

export function TabsTrigger({ className, ...props }: React.ComponentProps<typeof T.Trigger>) {
  return (
    <T.Trigger
      className={cn(
        "inline-flex h-9 cursor-pointer items-center justify-center gap-1.5 whitespace-nowrap rounded-full px-4 text-sm font-medium transition-all " +
          "data-[state=active]:bg-foreground data-[state=active]:text-background data-[state=active]:shadow-[0_6px_16px_-8px_rgb(0_0_0/0.5)] hover:text-foreground",
        className,
      )}
      {...props}
    />
  );
}

export function TabsContent({ className, ...props }: React.ComponentProps<typeof T.Content>) {
  return <T.Content className={cn("mt-4 focus-visible:outline-none", className)} {...props} />;
}
