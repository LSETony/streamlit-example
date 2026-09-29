"use client";
import * as React from "react";
import { Dialog as D } from "radix-ui";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";

export const Dialog = D.Root;
export const DialogTrigger = D.Trigger;
export const DialogClose = D.Close;

/**
 * Окно в стиле iOS. На телефоне — «шторка» снизу с хваталкой и скруглением 32 pt,
 * на планшете и компьютере — карточка по центру. sheet={false} — всегда по центру/сверху (например, поиск).
 */
export function DialogContent({ className, children, wide, hideClose, sheet = true, ...props }: React.ComponentProps<typeof D.Content> & {
  wide?: boolean; hideClose?: boolean; sheet?: boolean;
}) {
  return (
    <D.Portal>
      <D.Overlay className="fixed inset-0 z-50 bg-black/30 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=closed]:animate-out data-[state=closed]:fade-out-0" />
      <D.Content
        className={cn(
          "fixed z-50 grid gap-4 overflow-y-auto overscroll-contain bg-popover shadow-pop focus:outline-none dark:shadow-[0_0_0_0.5px_rgb(255_255_255/0.08),var(--elev-pop)]",
          sheet
            ? "inset-x-0 bottom-0 max-h-[92dvh] rounded-t-[32px] px-5 pb-[max(1.5rem,env(safe-area-inset-bottom))] pt-7 " +
                "data-[state=open]:animate-in data-[state=open]:slide-in-from-bottom data-[state=open]:duration-300 " +
                "sm:inset-x-auto sm:bottom-auto sm:left-1/2 sm:top-1/2 sm:max-h-[calc(100dvh-2rem)] sm:w-[calc(100vw-2rem)] sm:-translate-x-1/2 sm:-translate-y-1/2 " +
                "sm:rounded-[28px] sm:p-7 sm:data-[state=open]:slide-in-from-bottom-0 sm:data-[state=open]:zoom-in-95 sm:data-[state=open]:fade-in-0"
            : "left-1/2 top-1/2 max-h-[calc(100dvh-2rem)] w-[calc(100vw-2rem)] -translate-x-1/2 -translate-y-1/2 rounded-[28px] p-7 " +
                "data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95",
          wide ? "sm:max-w-2xl" : "sm:max-w-lg",
          !sheet && (wide ? "max-w-2xl" : "max-w-lg"),
          className,
        )}
        {...props}
      >
        {sheet ? <span aria-hidden className="absolute left-1/2 top-2 h-[5px] w-9 -translate-x-1/2 rounded-full bg-label-3 sm:hidden" /> : null}
        {children}
        {hideClose ? null : <D.Close className="absolute right-4 top-4 grid size-[30px] cursor-pointer place-items-center rounded-full bg-field text-muted-foreground hover:bg-field-hover hover:text-foreground" aria-label="Закрыть">
          <X className="size-4" strokeWidth={2.5} />
        </D.Close>}
      </D.Content>
    </D.Portal>
  );
}

export function DialogHeader({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex flex-col gap-1.5 pr-6", className)} {...props} />;
}

export function DialogTitle({ className, ...props }: React.ComponentProps<typeof D.Title>) {
  return <D.Title className={cn("text-[20px] font-bold leading-[25px] tracking-[-0.01em]", className)} {...props} />;
}

export function DialogDescription({ className, ...props }: React.ComponentProps<typeof D.Description>) {
  return <D.Description className={cn("text-sm text-muted-foreground", className)} {...props} />;
}

export function DialogFooter({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("flex flex-col-reverse gap-2 pt-1 sm:flex-row sm:justify-end [&>*]:w-full sm:[&>*]:w-auto", className)} {...props} />;
}
