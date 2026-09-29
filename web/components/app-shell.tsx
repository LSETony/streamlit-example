"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import {
  LayoutDashboard, ScanLine, Users, AlertTriangle, CalendarDays, Wallet, Tags, UserCog, ScrollText, Settings, LogOut, Menu, X, Moon, Sun, ChevronLeft,
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

const NAV: { title: string; items: NavItem[] }[] = [
  {
    title: "Работа",
    items: [
      { href: "/dashboard", label: "Дашборд", icon: LayoutDashboard, roles: ["owner", "admin"], feature: "dashboard" },
      { href: "/reception", label: "Ресепшен", icon: ScanLine, roles: ["owner", "admin", "reception"] },
      { href: "/clients", label: "Клиенты", icon: Users, roles: ["owner", "admin", "reception"] },
      { href: "/risk", label: "В зоне риска", icon: AlertTriangle, roles: ["owner", "admin", "reception"], feature: "risk" },
      { href: "/schedule", label: "Расписание", icon: CalendarDays, roles: ["owner", "admin", "reception"], feature: "schedule" },
    ],
  },
  {
    title: "Деньги",
    items: [
      { href: "/payments", label: "Оплаты", icon: Wallet, roles: ["owner", "admin"] },
      { href: "/plans", label: "Тарифы", icon: Tags, roles: ["owner"] },
    ],
  },
  {
    title: "Зал",
    items: [
      { href: "/staff", label: "Сотрудники", icon: UserCog, roles: ["owner"] },
      { href: "/audit", label: "Журнал действий", icon: ScrollText, roles: ["owner"], feature: "audit" },
      { href: "/settings", label: "Настройки", icon: Settings, roles: ["owner"] },
    ],
  },
];

export function AppShell({ role, features, gymName, userName, riskCount, children, banner }: {
  role: Role; features: Record<string, boolean>; gymName: string; userName: string; riskCount: number | null;
  children: React.ReactNode; banner?: React.ReactNode;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const groups = NAV.map((g) => ({
    ...g,
    items: g.items.filter((i) => i.roles.includes(role) && (!i.feature || features[i.feature] !== false)),
  })).filter((g) => g.items.length);

  const nav = (
    <nav className="-mx-1 flex flex-1 flex-col gap-5 overflow-y-auto px-1" aria-label="Разделы">
      {groups.map((g) => (
        <div key={g.title} className="grid gap-0.5">
          <p className="px-3 pb-1 text-[11px] font-medium uppercase tracking-[0.08em] text-sidebar-foreground/45">{g.title}</p>
          {g.items.map((item) => {
            const active = pathname === item.href || pathname.startsWith(item.href + "/");
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "group relative flex items-center gap-3 rounded-lg px-3 py-2 text-[14px] font-medium transition-colors",
                  active ? "bg-sidebar-muted text-white" : "text-sidebar-foreground hover:bg-sidebar-muted/50 hover:text-white",
                )}
              >
                {active ? <span aria-hidden className="absolute inset-y-2 -left-1 w-[3px] rounded-full bg-brand" /> : null}
                <Icon className={cn("size-[18px] shrink-0", active ? "text-brand" : "opacity-60 group-hover:opacity-100")} />
                <span className="flex-1">{item.label}</span>
                {item.href === "/risk" && riskCount ? (
                  <span className="min-w-6 rounded-full bg-white/10 px-1.5 text-center text-[11px] font-semibold text-white tabular">{riskCount}</span>
                ) : null}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );

  const gymCard = (
    <div className="flex items-center gap-3 rounded-xl bg-white/[0.04] p-2.5 ring-1 ring-white/[0.06]">
      <span className="grid size-9 shrink-0 place-items-center rounded-lg bg-brand text-sm font-bold text-brand-foreground">
        {gymName.trim()[0]?.toUpperCase() ?? "З"}
      </span>
      <span className="min-w-0">
        <span className="block truncate text-sm font-semibold text-white">{gymName}</span>
        <span className="block text-xs text-sidebar-foreground/60">Кабинет зала</span>
      </span>
    </div>
  );

  const footer = (
    <div className="flex items-center gap-3 border-t border-white/[0.07] pt-4">
      <span className="grid size-9 shrink-0 place-items-center rounded-full bg-white/10 text-xs font-semibold text-white">
        {userName.split(/\s+/).slice(0, 2).map((w) => w[0]).join("").toUpperCase()}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-white">{userName}</p>
        <p className="text-xs text-sidebar-foreground/60">{ROLE_LABEL[role]}</p>
      </div>
      <ThemeToggle />
      <form action={signOut}>
        <button className="grid size-8 cursor-pointer place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-muted hover:text-white" aria-label="Выйти" title="Выйти">
          <LogOut className="size-4" />
        </button>
      </form>
    </div>
  );

  return (
    <div className="flex min-h-dvh">
      <aside className="sticky top-0 hidden h-dvh w-64 shrink-0 flex-col gap-5 bg-sidebar px-4 pb-4 pt-6 lg:flex">
        <Link href="/" className="px-2 text-white" aria-label="core. — на главную">
          <Logo className="h-7" />
        </Link>
        {gymCard}
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
            <div className="flex items-center justify-between px-2 pt-2">
              <span className="text-white"><Logo className="h-6" /></span>
              <button onClick={() => setOpen(false)} className="rounded-lg p-2 text-white" aria-label="Закрыть меню">
                <X className="size-5" />
              </button>
            </div>
            {gymCard}
            {nav}
            {footer}
          </div>
        </div>
      ) : null}

      <main className="min-w-0 flex-1 pt-14 lg:pt-0">
        {banner}
        <div className="mx-auto w-full max-w-[1360px] px-4 py-6 sm:px-6 lg:px-10 lg:py-9">{children}</div>
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
    <button onClick={toggle} className="grid size-8 cursor-pointer place-items-center rounded-lg text-sidebar-foreground hover:bg-sidebar-muted hover:text-white" aria-label="Сменить тему" title="Сменить тему">
      <Sun className="hidden size-4 dark:block" />
      <Moon className="size-4 dark:hidden" />
    </button>
  );
}

export function PageHeader({ title, description, actions, back }: {
  title: React.ReactNode; description?: React.ReactNode; actions?: React.ReactNode; back?: { href: string; label: string };
}) {
  return (
    <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
      <div className="grid gap-1.5">
        {back ? (
          <Link href={back.href} className="-ml-0.5 inline-flex w-fit items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
            <ChevronLeft className="size-4" /> {back.label}
          </Link>
        ) : null}
        <h1 className="text-[26px] font-bold leading-tight tracking-[-0.02em] sm:text-[30px]">{title}</h1>
        {description ? <p className="text-sm text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}
