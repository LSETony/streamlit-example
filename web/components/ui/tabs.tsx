"use client";
import * as React from "react";
import { Tabs as T } from "radix-ui";
import { cn } from "@/lib/utils";
import { useTx } from "@/lib/i18n/client";

export const Tabs = T.Root;

/** Сегментированный переключатель iOS: серая дорожка, белый «ползунок» у выбранного сегмента */
export function TabsList({ className, ...props }: React.ComponentProps<typeof T.List>) {
  return (
    <T.List
      className={cn("inline-flex h-9 max-w-full items-center overflow-x-auto rounded-full bg-field p-[3px] text-foreground", className)}
      {...props}
    />
  );
}

export function TabsTrigger({ className, children, ...props }: React.ComponentProps<typeof T.Trigger>) {
  const tx = useTx();
  return (
    <T.Trigger className={cn(segmentClass, "data-[state=active]:bg-[var(--segment-thumb)]", className)} {...props}>{tx(children)}</T.Trigger>
  );
}

export const segmentClass =
  "inline-flex h-full min-w-16 cursor-pointer select-none items-center justify-center gap-1.5 whitespace-nowrap rounded-full px-4 text-[13px] font-semibold " +
  "text-foreground/75 transition-[background-color,box-shadow,color] duration-200 hover:text-foreground " +
  "data-[state=active]:text-foreground data-[state=active]:shadow-[0_3px_8px_rgb(0_0_0/0.12),0_3px_1px_rgb(0_0_0/0.04)] " +
  "aria-pressed:bg-[var(--segment-thumb)] aria-pressed:text-foreground aria-pressed:shadow-[0_3px_8px_rgb(0_0_0/0.12),0_3px_1px_rgb(0_0_0/0.04)] " +
  "aria-[current=page]:bg-[var(--segment-thumb)] aria-[current=page]:text-foreground aria-[current=page]:shadow-[0_3px_8px_rgb(0_0_0/0.12),0_3px_1px_rgb(0_0_0/0.04)]";

/** Та же дорожка для кнопок и ссылок (выбранный сегмент — aria-pressed или aria-current="page") */
export function Segmented({ className, ...props }: React.ComponentProps<"div">) {
  return <div role="group" className={cn("inline-flex h-9 max-w-full items-center overflow-x-auto rounded-full bg-field p-[3px]", className)} {...props} />;
}

export function TabsContent({ className, ...props }: React.ComponentProps<typeof T.Content>) {
  return <T.Content className={cn("mt-4 focus-visible:outline-none", className)} {...props} />;
}
