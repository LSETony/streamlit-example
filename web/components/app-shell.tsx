"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import {
  LayoutDashboard, ScanLine, Users, AlertTriangle, CalendarDays, Wallet, Tags, UserCog, ScrollText, Settings, LogOut, Menu, X, Moon, Sun,
} from "lucide-react";
import { Logo } from "@/components/logo";
import { cn } from "@/lib/utils";
import { signOut } from "@/app/actions/auth";
import type { Role } from "@/lib/types";
import { ROLE_LABEL } from "@/lib/types";

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  roles: Role[];
  feature?: string;
}

const NAV: NavItem[] = [
  { href: "/dashboard", label: "Дашборд", icon: LayoutDashboard, roles: ["owner", "admin"], feature: "dashboard" },
  { href: "/reception", label: "Ресепшен", icon: ScanLine, roles: ["owner", "admin", "reception"] },
  { href: "/clients", label: "Клиенты", icon: Users, roles: ["owner", "admin", "reception"] },
  { href: "/risk", label: "В зоне риска", icon: AlertTriangle, roles: ["owner", "admin", "reception"], feature: "risk" },
  { href: "/schedule", label: "Расписание", icon: CalendarDays, roles: ["owner", "admin", "reception"], feature: "schedule" },
  { href: "/payments", label: "Оплаты", icon: Wallet, roles: ["owner", "admin"] },
  { href: "/plans", label: "Тарифы", icon: Tags, roles: ["owner"] },
  { href: "/staff", label: "Сотрудники", icon: UserCog, roles: ["owner"] },
  { href: "/audit", label: "Журнал действий", icon: ScrollText, roles: ["owner"], feature: "audit" },
  { href: "/settings", label: "Настройки зала", icon: Settings, roles: ["owner"] },
];

export function AppShell({ role, features, gymName, userName, riskCount, children, banner }: {
  role: Role; features: Record<string, boolean>; gymName: string; userName: string; riskCount: number | null;
  children: React.ReactNode; banner?: React.ReactNode;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const items = NAV.filter((i) => i.roles.includes(role) && (!i.feature || features[i.feature] !== false));

  const nav = (
    <nav className="flex flex-1 flex-col gap-0.5" aria-label="Разделы">
      {items.map((item) => {
        const active = pathname === item.href || pathname.startsWith(item.href + "/");
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            onClick={() => setOpen(false)}
            className={cn(
              "group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors",
              active ? "bg-sidebar-muted text-white" : "text-sidebar-foreground hover:bg-sidebar-muted/60 hover:text-white",
            )}
          >
            <Icon className={cn("size-[18px] shrink-0", active ? "text-brand" : "opacity-70 group-hover:opacity-100")} />
            <span className="flex-1">{item.label}</span>
            {item.href === "/risk" && riskCount ? (
              <span className="rounded-full bg-brand px-1.5 text-[11px] font-semibold text-brand-foreground tabular">{riskCount}</span>
            ) : null}
          </Link>
        );
      })}
    </nav>
  );

  const footer = (
    <div className="grid gap-2 border-t border-white/10 pt-4">
      <div className="px-3">
        <p className="truncate text-sm font-medium text-white">{userName}</p>
        <p className="text-xs text-sidebar-foreground/70">{ROLE_LABEL[role]}</p>
      </div>
      <div className="flex gap-1">
        <ThemeToggle />
        <form action={signOut} className="flex-1">
          <button className="flex w-full cursor-pointer items-center gap-2 rounded-xl px-3 py-2 text-sm text-sidebar-foreground hover:bg-sidebar-muted/60 hover:text-white">
            <LogOut className="size-4" /> Выйти
          </button>
        </form>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-dvh">
      <aside className="sticky top-0 hidden h-dvh w-60 shrink-0 flex-col gap-6 bg-sidebar p-4 lg:flex">
        <Link href="/" className="px-3 pt-2 text-white">
          <Logo className="h-8" />
        </Link>
        <p className="-mt-4 truncate px-3 text-xs text-sidebar-foreground/70">{gymName}</p>
        {nav}
        {footer}
      </aside>

      {/* мобильная и планшетная шапка */}
      <div className="fixed inset-x-0 top-0 z-40 flex h-14 items-center justify-between bg-sidebar px-4 lg:hidden">
        <Link href="/" className="text-white"><Logo className="h-6" /></Link>
        <span className="mx-3 flex-1 truncate text-center text-xs text-sidebar-foreground">{gymName}</span>
        <button onClick={() => setOpen(true)} className="rounded-lg p-2 text-white" aria-label="Меню">
          <Menu className="size-5" />
        </button>
      </div>
      {open ? (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true">
          <div className="absolute inset-0 bg-black/50" onClick={() => setOpen(false)} />
          <div className="absolute inset-y-0 right-0 flex w-72 max-w-[85vw] flex-col gap-6 bg-sidebar p-4 animate-in slide-in-from-right">
            <div className="flex items-center justify-between px-3 pt-2">
              <span className="text-white"><Logo className="h-6" /></span>
              <button onClick={() => setOpen(false)} className="rounded-lg p-2 text-white" aria-label="Закрыть меню">
                <X className="size-5" />
              </button>
            </div>
            {nav}
            {footer}
          </div>
        </div>
      ) : null}

      <main className="min-w-0 flex-1 pt-14 lg:pt-0">
        {banner}
        <div className="mx-auto w-full max-w-[1400px] px-4 py-6 sm:px-6 lg:px-8 lg:py-8">{children}</div>
      </main>
    </div>
  );
}

function ThemeToggle() {
  const toggle = () => {
    const root = document.documentElement;
    const isDark = root.dataset.theme
      ? root.dataset.theme === "dark"
      : window.matchMedia("(prefers-color-scheme: dark)").matches;
    const next = isDark ? "light" : "dark";
    root.dataset.theme = next;
    try {
      localStorage.setItem("core-theme", next);
    } catch {
      /* приватный режим */
    }
  };
  return (
    <button onClick={toggle} className="cursor-pointer rounded-xl px-3 py-2 text-sidebar-foreground hover:bg-sidebar-muted/60 hover:text-white" aria-label="Сменить тему">
      <Sun className="hidden size-4 dark:block" />
      <Moon className="size-4 dark:hidden" />
    </button>
  );
}

export function PageHeader({ title, description, actions }: { title: string; description?: React.ReactNode; actions?: React.ReactNode }) {
  return (
    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div className="grid gap-1">
        <h1 className="text-2xl font-bold tracking-tight sm:text-[28px]">{title}</h1>
        {description ? <p className="text-sm text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap gap-2">{actions}</div> : null}
    </div>
  );
}
