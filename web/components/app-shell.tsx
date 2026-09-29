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
        <div key={g.title} className="grid gap-1">
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
                  "group flex items-center gap-3 rounded-[18px] p-1 pr-3 text-[14px] font-medium transition-colors",
                  active ? "bg-white/[0.06] text-white" : "text-sidebar-foreground hover:bg-white/[0.04] hover:text-white",
                )}
              >
                <span
                  className={cn(
                    "grid size-9 shrink-0 place-items-center rounded-[14px] transition-colors",
                    active
                      ? "bg-[linear-gradient(135deg,#f92c00,#b0179a_55%,#5900ff)] text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.3),0_8px_18px_-8px_rgb(249_44_0/0.7)]"
                      : "bg-white/[0.05] ring-1 ring-inset ring-white/[0.07] group-hover:bg-white/[0.09]",
                  )}
                >
                  <Icon className={cn("size-[18px]", active ? "" : "opacity-70 group-hover:opacity-100")} />
                </span>
                <span className="flex-1">{item.label}</span>
                {item.href === "/risk" && riskCount ? (
                  <span className="grid h-7 min-w-7 place-items-center rounded-full px-1.5 text-[11px] font-semibold text-white ring-1 ring-inset ring-white/20 tabular">{riskCount}</span>
                ) : null}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );

  const gymCard = (
    <div className="flex items-center gap-3 rounded-[20px] bg-white/[0.05] p-2 ring-1 ring-inset ring-white/[0.07]">
      <span className="grid size-10 shrink-0 place-items-center rounded-[14px] bg-brand text-sm font-bold text-brand-foreground shadow-[inset_0_1px_0_rgb(255_255_255/0.3)]">
        {gymName.trim()[0]?.toUpperCase() ?? "З"}
      </span>
      <span className="min-w-0">
        <span className="block truncate text-sm font-semibold text-white">{gymName}</span>
        <span className="block text-xs text-sidebar-foreground/60">Кабинет зала</span>
      </span>
    </div>
  );

  const footer = (
    <div className="flex items-center gap-2.5 rounded-[20px] bg-white/[0.05] p-2 ring-1 ring-inset ring-white/[0.07]">
      <span className="grid size-10 shrink-0 place-items-center rounded-full bg-white/10 text-xs font-semibold text-white">
        {userName.split(/\s+/).slice(0, 2).map((w) => w[0]).join("").toUpperCase()}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-medium text-white">{userName}</p>
        <p className="text-xs text-sidebar-foreground/60">{ROLE_LABEL[role]}</p>
      </div>
      <ThemeToggle />
      <form action={signOut}>
        <button className="grid size-9 cursor-pointer place-items-center rounded-[12px] bg-white/[0.05] text-sidebar-foreground hover:bg-white/10 hover:text-white" aria-label="Выйти" title="Выйти">
          <LogOut className="size-4" />
        </button>
      </form>
    </div>
  );

  return (
    <div className="flex min-h-dvh">
      <aside className="sticky top-0 hidden h-dvh w-[288px] shrink-0 p-3 lg:block">
        <div className="glass-dark flex h-full flex-col gap-5 rounded-[32px] px-3 pb-3 pt-6">
          <Link href="/" className="px-3 text-white" aria-label="core. — на главную">
            <Logo className="h-6" />
          </Link>
          {gymCard}
          {nav}
          {footer}
        </div>
      </aside>

      {/* мобильная и планшетная шапка */}
      <div className="glass-dark fixed inset-x-3 top-3 z-40 flex h-14 items-center justify-between rounded-[22px] pl-5 pr-2 lg:hidden">
        <Link href="/" className="text-white"><Logo className="h-5" /></Link>
        <span className="mx-3 flex-1 truncate text-center text-xs text-sidebar-foreground">{gymName}</span>
        <button onClick={() => setOpen(true)} className="grid size-10 place-items-center rounded-[14px] bg-white/[0.06] text-white" aria-label="Меню">
          <Menu className="size-5" />
        </button>
      </div>
      {open ? (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true">
          <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <div className="glass-dark absolute inset-y-2 right-2 flex w-72 max-w-[85vw] flex-col gap-5 rounded-[28px] p-3 animate-in slide-in-from-right">
            <div className="flex items-center justify-between px-2 pt-2">
              <span className="text-white"><Logo className="h-5" /></span>
              <button onClick={() => setOpen(false)} className="grid size-10 place-items-center rounded-[14px] bg-white/[0.06] text-white" aria-label="Закрыть меню">
                <X className="size-5" />
              </button>
            </div>
            {gymCard}
            {nav}
            {footer}
          </div>
        </div>
      ) : null}

      <main className="min-w-0 flex-1 pt-[72px] lg:pt-0">
        {banner}
        <div className="mx-auto w-full max-w-[1360px] px-4 py-6 sm:px-6 lg:px-8 lg:py-9">{children}</div>
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
    <button onClick={toggle} className="grid size-9 cursor-pointer place-items-center rounded-[12px] bg-white/[0.05] text-sidebar-foreground hover:bg-white/10 hover:text-white" aria-label="Сменить тему" title="Сменить тему">
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
        <h1 className="text-[28px] font-semibold leading-tight tracking-[-0.03em] sm:text-[36px]">{title}</h1>
        {description ? <p className="text-sm text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}
