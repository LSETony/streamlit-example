"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import {
  LayoutDashboard, ScanLine, Users, AlertTriangle, CalendarDays, Wallet, Tags, UserCog, ScrollText, Settings, LogOut, X, Moon, Sun, ChevronLeft,
  Search, UserPlus, LayoutGrid,
} from "lucide-react";
import { Logo } from "@/components/logo";
import { CommandMenu, Kbd } from "@/components/command-menu";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { signOut } from "@/app/actions/auth";
import type { Role } from "@/lib/types";
import { ROLE_LABEL } from "@/lib/types";

interface NavItem {
  href: string;
  label: string;
  short?: string;
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
      { href: "/risk", label: "В зоне риска", short: "Риск", icon: AlertTriangle, roles: ["owner", "admin", "reception"], feature: "risk" },
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

/** Порядок вкладок нижней панели на телефоне: сначала то, чем пользуются каждый день */
const TAB_PRIORITY = ["/reception", "/clients", "/schedule", "/dashboard", "/risk"];

const GRADIENT_TILE =
  "bg-[linear-gradient(135deg,#f92c00,#b0179a_55%,#5900ff)] text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.3),0_8px_18px_-8px_rgb(249_44_0/0.7)]";

export function AppShell({ role, features, gymId, gymName, userName, riskCount, readOnly, children, banner }: {
  role: Role; features: Record<string, boolean>; gymId: string; gymName: string; userName: string; riskCount: number | null;
  readOnly: boolean; children: React.ReactNode; banner?: React.ReactNode;
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState(false);
  const groups = NAV.map((g) => ({
    ...g,
    items: g.items.filter((i) => i.roles.includes(role) && (!i.feature || features[i.feature] !== false)),
  })).filter((g) => g.items.length);
  const items = groups.flatMap((g) => g.items);
  const isActive = (href: string) => pathname === href || pathname.startsWith(href + "/");
  const tabs = TAB_PRIORITY.map((h) => items.find((i) => i.href === h)).filter((i): i is NavItem => !!i).slice(0, 4);
  const moreActive = !tabs.some((t) => isActive(t.href));

  // Ctrl/⌘+K открывает поиск с любой страницы
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setSearch((v) => !v);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const badge = (href: string) =>
    href === "/risk" && riskCount ? (
      <span className="grid h-6 min-w-6 place-items-center rounded-full bg-brand px-1.5 text-[11px] font-semibold text-white tabular">{riskCount}</span>
    ) : null;

  const nav = (
    <nav className="-mx-1 flex flex-1 flex-col gap-5 overflow-y-auto px-1" aria-label="Разделы">
      {groups.map((g) => (
        <div key={g.title} className="grid gap-1">
          <p className="px-3 pb-1 text-[11px] font-medium uppercase tracking-[0.08em] text-sidebar-foreground/45">{g.title}</p>
          {g.items.map((item) => {
            const active = isActive(item.href);
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setOpen(false)}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "group flex items-center gap-3 rounded-[18px] p-1 pr-3 text-[14px] font-medium transition-colors",
                  active ? "bg-white/[0.07] text-white" : "text-sidebar-foreground hover:bg-white/[0.04] hover:text-white",
                )}
              >
                <span
                  className={cn(
                    "grid size-9 shrink-0 place-items-center rounded-[14px] transition-colors",
                    active ? GRADIENT_TILE : "bg-white/[0.05] ring-1 ring-inset ring-white/[0.07] group-hover:bg-white/[0.09]",
                  )}
                >
                  <Icon className={cn("size-[18px]", active ? "" : "opacity-70 group-hover:opacity-100")} />
                </span>
                <span className="flex-1">{item.label}</span>
                {badge(item.href)}
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

  const canAddClient = !readOnly && items.some((i) => i.href === "/clients");
  const canCheckIn = items.some((i) => i.href === "/reception");

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

      {/* телефон и планшет: шапка сверху, вкладки снизу */}
      <div className="glass-dark fixed inset-x-3 top-3 z-40 flex h-14 items-center gap-2 rounded-[22px] pl-5 pr-2 lg:hidden">
        <Link href="/" className="text-white" aria-label="core. — на главную"><Logo className="h-5" /></Link>
        <span className="mx-2 flex-1 truncate text-center text-xs text-sidebar-foreground">{gymName}</span>
        <button onClick={() => setSearch(true)} className="grid size-10 place-items-center rounded-[14px] bg-white/[0.06] text-white" aria-label="Поиск">
          <Search className="size-5" />
        </button>
      </div>
      <nav className="glass-dark fixed inset-x-3 bottom-3 z-40 grid h-16 grid-flow-col auto-cols-fr items-center rounded-[24px] px-1.5 pb-[env(safe-area-inset-bottom)] lg:hidden" aria-label="Основные разделы">
        {tabs.map((t) => {
          const active = isActive(t.href);
          return (
            <Link key={t.href} href={t.href} aria-current={active ? "page" : undefined}
              className={cn("relative flex flex-col items-center gap-1 text-[11px] font-medium", active ? "text-white" : "text-sidebar-foreground")}>
              <span className={cn("grid h-8 w-12 place-items-center rounded-full transition-colors", active ? GRADIENT_TILE : "")}>
                <t.icon className="size-[18px]" />
              </span>
              {t.short ?? t.label}
              {t.href === "/risk" && riskCount ? <span className="absolute -top-0.5 left-1/2 ml-2 size-2 rounded-full bg-brand" aria-hidden /> : null}
            </Link>
          );
        })}
        <button onClick={() => setOpen(true)} className={cn("flex cursor-pointer flex-col items-center gap-1 text-[11px] font-medium", moreActive ? "text-white" : "text-sidebar-foreground")}>
          <span className={cn("grid h-8 w-12 place-items-center rounded-full", moreActive ? GRADIENT_TILE : "")}>
            <LayoutGrid className="size-[18px]" />
          </span>
          Ещё
        </button>
      </nav>
      {open ? (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true" aria-label="Меню">
          <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <div className="glass-dark absolute inset-x-2 bottom-2 flex max-h-[85dvh] flex-col gap-4 rounded-[28px] p-3 animate-in slide-in-from-bottom-8 fade-in-0">
            <div className="flex items-center justify-between pl-3">
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

      <main className="min-w-0 flex-1 pb-24 pt-[72px] lg:pb-0 lg:pt-0">
        {banner}
        <div className="mx-auto w-full max-w-[1360px] px-4 py-6 sm:px-6 lg:px-8 lg:py-6">
          {/* верхняя панель: поиск и частые действия */}
          <div className="mb-6 hidden items-center gap-3 lg:flex">
            <button onClick={() => setSearch(true)}
              className="glass flex h-11 w-full max-w-md cursor-pointer items-center gap-3 rounded-full pl-4 pr-2 text-sm text-muted-foreground transition-colors hover:text-foreground">
              <Search className="size-4" />
              <span className="flex-1 text-left">Найти клиента или раздел</span>
              <Kbd>Ctrl K</Kbd>
            </button>
            <div className="ml-auto flex items-center gap-2">
              {canCheckIn && !isActive("/reception") ? (
                <Button variant="outline" asChild><Link href="/reception"><ScanLine /> Отметить визит</Link></Button>
              ) : null}
              {canAddClient ? (
                <Button variant="brand" asChild><Link href="/clients?new=1"><UserPlus /> Клиент</Link></Button>
              ) : null}
            </div>
          </div>
          {children}
        </div>
      </main>

      <CommandMenu open={search} onOpenChange={setSearch} gymId={gymId} sections={items} readOnly={readOnly} />
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
      <div className="grid min-w-0 gap-1.5">
        {back ? (
          <Link href={back.href} className="-ml-0.5 inline-flex w-fit items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
            <ChevronLeft className="size-4" /> {back.label}
          </Link>
        ) : null}
        <h1 className="text-[28px] font-semibold leading-tight tracking-[-0.03em] sm:text-[34px]">{title}</h1>
        {description ? <p className="text-sm text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}
