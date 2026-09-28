import * as React from "react";
import { cn } from "@/lib/utils";

export function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("animate-pulse rounded-lg bg-muted", className)} {...props} />;
}

export function Separator({ className }: { className?: string }) {
  return <div role="separator" className={cn("h-px w-full bg-border", className)} />;
}

export function Alert({ className, variant = "default", ...props }: React.ComponentProps<"div"> & { variant?: "default" | "warning" | "danger" | "success" }) {
  const styles = {
    default: "border-border bg-muted/50",
    warning: "border-warning/40 bg-warning/10",
    danger: "border-destructive/40 bg-destructive/10 text-destructive",
    success: "border-success/40 bg-success/10",
  }[variant];
  return <div role="status" className={cn("rounded-xl border px-4 py-3 text-sm", styles, className)} {...props} />;
}

export function EmptyState({ icon, title, children, action, className }: {
  icon?: React.ReactNode; title: string; children?: React.ReactNode; action?: React.ReactNode; className?: string;
}) {
  return (
    <div className={cn("flex flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-border px-6 py-14 text-center", className)}>
      {icon ? <div className="rounded-2xl bg-muted p-3 text-muted-foreground [&_svg]:size-6">{icon}</div> : null}
      <div className="grid gap-1">
        <p className="font-semibold">{title}</p>
        {children ? <div className="max-w-md text-sm text-muted-foreground">{children}</div> : null}
      </div>
      {action}
    </div>
  );
}

export function Avatar({ name, src, className }: { name: string; src?: string | null; className?: string }) {
  const initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]?.toUpperCase()).join("");
  return src ? (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={src} alt="" className={cn("size-10 shrink-0 rounded-full object-cover", className)} />
  ) : (
    <div className={cn("grid size-10 shrink-0 place-items-center rounded-full bg-muted text-sm font-semibold text-muted-foreground", className)}>
      {initials || "?"}
    </div>
  );
}
