"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { createContext, useContext, useEffect, useMemo, useRef, useState, useSyncExternalStore } from "react";
import {
  LayoutDashboard, ScanLine, Users, AlertTriangle, CalendarDays, Wallet, Tags, UserCog, ScrollText, Settings, LogOut, X, Moon, Sun, ChevronLeft,
  Search, Plus, LayoutGrid,
} from "lucide-react";
import { Logo } from "@/components/logo";
import { CommandMenu, Kbd } from "@/components/command-menu";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { signOut } from "@/app/actions/auth";
import type { Role } from "@/lib/types";
import { ROLE_LABEL } from "@/lib/types";
import { useT, useTx } from "@/lib/i18n/client";
import { LanguageSwitch } from "@/components/language-switch";

const noSubscribe = () => () => {};

interface NavItem {
  href: string;
  label: string;
  short?: string;
  icon: React.ComponentType<{ className?: string; strokeWidth?: number }>;
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

/**
 * Крупный заголовок страницы (как в iOS) сообщает навигационной панели свой текст и виден ли он:
 * когда заголовок уходит под панель при прокрутке, в панели появляется компактный заголовок.
 */
const NavTitleContext = createContext<{ setTitle: (t: string | null) => void; setCollapsed: (v: boolean) => void } | null>(null);

export function AppShell({ role, features, gymId, gymName, userName, riskCount, readOnly, children, banner }: {
  role: Role; features: Record<string, boolean>; gymId: string; gymName: string; userName: string; riskCount: number | null;
  readOnly: boolean; children: React.ReactNode; banner?: React.ReactNode;
}) {
  const tr = useT();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [search, setSearch] = useState(false);
  const [title, setTitle] = useState<string | null>(null);
  const [collapsed, setCollapsed] = useState(false);
  const groups = NAV.map((g) => ({
    ...g,
    items: g.items.filter((i) => i.roles.includes(role) && (!i.feature || features[i.feature] !== false)),
  })).filter((g) => g.items.length);
  const items = groups.flatMap((g) => g.items);
  const isActive = (href: string) => pathname === href || pathname.startsWith(href + "/");
  const tabs = TAB_PRIORITY.map((h) => items.find((i) => i.href === h)).filter((i): i is NavItem => !!i).slice(0, 4);
  const moreActive = !tabs.some((t) => isActive(t.href));
  const canAddClient = !readOnly && items.some((i) => i.href === "/clients");
  const canCheckIn = items.some((i) => i.href === "/reception");
  const inlineTitle = collapsed && title ? title : null;
  const navTitle = useMemo(() => ({ setTitle, setCollapsed }), []);

  // Как в Safari: на телефоне и планшете верхняя панель уезжает при прокрутке вниз и возвращается при прокрутке вверх
  const [barHidden, setBarHidden] = useState(false);
  useEffect(() => {
    let last = window.scrollY;
    const onScroll = () => {
      const y = window.scrollY;
      if (Math.abs(y - last) < 8) return;
      setBarHidden(y > last && y > 120);
      last = y;
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);
  // при переходе на другую страницу панель снова видна
  const [barPath, setBarPath] = useState(pathname);
  if (barPath !== pathname) {
    setBarPath(pathname);
    setBarHidden(false);
  }

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

  const badge = (href: string, active: boolean) =>
    href === "/risk" && riskCount ? (
      <span className={cn("grid h-[22px] min-w-[22px] place-items-center rounded-full px-1.5 text-[12px] font-semibold tabular",
        active ? "bg-white/25 text-white" : "bg-brand text-white")}>{riskCount}</span>
    ) : null;

  // Боковая панель iPadOS: иконки цветом акцента, выбранный раздел залит акцентом
  const nav = (
    <nav className="-mx-1 flex flex-1 flex-col gap-4 overflow-y-auto px-1" aria-label={tr("Разделы")}>
      {groups.map((g) => (
        <div key={g.title} className="grid gap-0.5">
          <p className="px-3 pb-1 text-[13px] font-semibold text-muted-foreground">{tr(g.title)}</p>
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
                  "flex h-11 items-center gap-3 rounded-xl px-3 text-[15px] font-medium transition-colors active:opacity-70",
                  active ? "bg-tint text-white" : "text-foreground hover:bg-field",
                )}
              >
                <Icon className={cn("size-5 shrink-0", active ? "text-white" : "text-tint-text")} strokeWidth={2} />
                <span className="flex-1 truncate">{tr(item.label)}</span>
                {badge(item.href, active)}
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );

  const gymCard = (
    <div className="flex items-center gap-3 px-2">
      <span className="grid size-10 shrink-0 place-items-center rounded-full bg-brand text-[17px] font-bold text-white">
        {gymName.trim()[0]?.toUpperCase() ?? "З"}
      </span>
      <span className="min-w-0">
        <span className="block truncate text-[15px] font-semibold">{gymName}</span>
        <span className="block text-[13px] text-muted-foreground">{tr("Кабинет зала")}</span>
      </span>
    </div>
  );

  const footer = (
    <div className="grid gap-2 rounded-2xl bg-field p-2">
    <div className="flex items-center gap-2.5">
      <span className="grid size-9 shrink-0 place-items-center rounded-full bg-[linear-gradient(180deg,#a5a5ab,#86868c)] text-[13px] font-semibold text-white">
        {userName.split(/\s+/).slice(0, 2).map((w) => w[0]).join("").toUpperCase()}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-[15px] font-medium">{userName}</p>
        <p className="text-[13px] text-muted-foreground">{tr(ROLE_LABEL[role])}</p>
      </div>
      <ThemeToggle />
      <form action={signOut}>
        <button className="grid size-9 cursor-pointer place-items-center rounded-full text-tint-text hover:bg-field-hover active:opacity-60" aria-label={tr("Выйти")} title={tr("Выйти")}>
          <LogOut className="size-[18px]" />
        </button>
      </form>
    </div>
    <div className="flex items-center justify-between gap-2 border-t border-separator/60 px-1 pt-2">
      <span className="text-[13px] text-muted-foreground">{tr("Язык")}</span>
      <LanguageSwitch />
    </div>
    </div>
  );

  return (
    <NavTitleContext.Provider value={navTitle}>
      <div className="flex min-h-dvh">
        <aside className="sticky top-0 hidden h-dvh w-[300px] shrink-0 px-3 pb-3 pt-[max(0.75rem,env(safe-area-inset-top))] pl-[max(0.75rem,env(safe-area-inset-left))] lg:block">
          <div className="glass glass-rim relative flex h-full flex-col gap-5 rounded-[28px] px-3 pb-3 pt-6">
            <Link href="/" className="px-3 text-foreground" aria-label={tr("core. — на главную")}>
              <Logo className="h-6" />
            </Link>
            {gymCard}
            {nav}
            {footer}
          </div>
        </aside>

        <main className="min-w-0 flex-1 pb-[calc(env(safe-area-inset-bottom)+7rem)] pl-[env(safe-area-inset-left)] pr-[env(safe-area-inset-right)] pt-[calc(env(safe-area-inset-top)+5rem)] short:pb-[calc(env(safe-area-inset-bottom)+4.5rem)] short:pt-[calc(env(safe-area-inset-top)+4rem)] lg:pb-10 lg:pl-0 lg:pt-[env(safe-area-inset-top)]">
          {banner}
          <div className="mx-auto w-full max-w-[1600px] px-4 py-2 sm:px-6 lg:px-8 lg:py-6">
            <div className="hidden h-[52px] lg:mb-5 lg:block" aria-hidden />
            {children}
          </div>
        </main>

        {open ? (
          <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true" aria-label={tr("Меню")}>
            <div className="absolute inset-0 bg-black/30 animate-in fade-in-0" onClick={() => setOpen(false)} />
            <div className="absolute inset-x-0 bottom-0 flex max-h-[88dvh] flex-col gap-4 rounded-t-[32px] bg-popover px-4 pb-[max(1rem,env(safe-area-inset-bottom))] pt-7 shadow-pop animate-in slide-in-from-bottom duration-300">
              <span aria-hidden className="absolute left-1/2 top-2 h-[5px] w-9 -translate-x-1/2 rounded-full bg-label-3" />
              <div className="flex items-center justify-between pl-2">
                <span className="text-foreground"><Logo className="h-5" /></span>
                <button onClick={() => setOpen(false)} className="grid size-[30px] place-items-center rounded-full bg-field text-muted-foreground" aria-label={tr("Закрыть меню")}>
                  <X className="size-4" strokeWidth={2.5} />
                </button>
              </div>
              {gymCard}
              {nav}
              {footer}
            </div>
          </div>
        ) : null}

        {/* Плавающие панели идут в DOM после содержимого: иначе Chromium не размывает то, что под ними */}

        {/* телефон и iPad в портрете: навигационная панель сверху, вкладки снизу (iOS 26) */}
        <div className={cn("glass glass-rim fixed left-[max(0.75rem,env(safe-area-inset-left))] right-[max(0.75rem,env(safe-area-inset-right))] top-[max(0.75rem,env(safe-area-inset-top))] z-40 flex h-14 items-center gap-2 rounded-full pl-5 pr-1.5 transition-transform duration-300 short:top-[max(0.5rem,env(safe-area-inset-top))] short:h-12 lg:hidden",
          barHidden && "-translate-y-[calc(100%+env(safe-area-inset-top)+1rem)]")}>
          <div className="relative min-w-0 flex-1">
            <Link href="/" aria-label={tr("core. — на главную")}
              className={cn("block w-fit text-foreground transition-all duration-300", inlineTitle && "pointer-events-none -translate-y-2 opacity-0")}>
              <Logo className="h-5" />
            </Link>
            <p aria-hidden={!inlineTitle}
              className={cn("absolute inset-0 truncate text-[17px] font-semibold leading-5 transition-all duration-300 flex items-center",
                inlineTitle ? "translate-y-0 opacity-100" : "pointer-events-none translate-y-2 opacity-0")}>
              {title}
            </p>
          </div>
          <button onClick={() => setSearch(true)} className="grid size-11 place-items-center rounded-full text-tint-text hover:bg-field active:opacity-60" aria-label={tr("Поиск")}>
            <Search className="size-[22px]" />
          </button>
          {canAddClient ? (
            <Link href="/clients?new=1" className="grid size-11 place-items-center rounded-full bg-tint text-white active:opacity-80" aria-label={tr("Новый клиент")}>
              <Plus className="size-6" />
            </Link>
          ) : null}
        </div>
        <nav className="glass glass-rim fixed bottom-[max(0.75rem,env(safe-area-inset-bottom))] left-[max(0.75rem,env(safe-area-inset-left))] right-[max(0.75rem,env(safe-area-inset-right))] z-40 grid h-16 grid-flow-col auto-cols-fr items-center gap-1 rounded-full p-1 short:bottom-[max(0.5rem,env(safe-area-inset-bottom))] md:left-1/2 md:right-auto md:h-14 md:-translate-x-1/2 md:auto-cols-max md:p-1.5 short:left-1/2 short:right-auto short:h-12 short:-translate-x-1/2 short:auto-cols-max short:p-1 lg:hidden" aria-label={tr("Основные разделы")}>
          {tabs.map((tab) => {
            const active = isActive(tab.href);
            return (
              <Link key={tab.href} href={tab.href} aria-current={active ? "page" : undefined}
                className={cn("relative flex h-full flex-col items-center justify-center gap-0.5 rounded-full text-[10px] font-semibold transition-colors active:opacity-60 md:flex-row md:gap-2 md:px-5 md:text-[15px] short:flex-row short:gap-1.5 short:px-4 short:text-[13px]",
                  active ? "bg-field text-tint-text" : "text-foreground/80")}>
                <tab.icon className="size-[22px]" strokeWidth={active ? 2.25 : 1.9} />
                {tr(tab.short ?? tab.label)}
                {tab.href === "/risk" && riskCount ? <span className="absolute right-[22%] top-2 size-2 rounded-full bg-brand md:right-2" aria-hidden /> : null}
              </Link>
            );
          })}
          <button onClick={() => setOpen(true)}
            className={cn("flex h-full cursor-pointer flex-col items-center justify-center gap-0.5 rounded-full text-[10px] font-semibold active:opacity-60 md:flex-row md:gap-2 md:px-5 md:text-[15px] short:flex-row short:gap-1.5 short:px-4 short:text-[13px]",
              moreActive ? "bg-field text-tint-text" : "text-foreground/80")}>
            <LayoutGrid className="size-[22px]" strokeWidth={moreActive ? 2.25 : 1.9} />
            {tr("Ещё")}
          </button>
        </nav>

        {/* iPad в альбоме и компьютер: навигационная панель над колонкой содержимого */}
        <div className="glass glass-rim fixed top-[max(0.75rem,env(safe-area-inset-top))] z-30 hidden h-[52px] items-center gap-2 rounded-full p-1.5 pl-5 lg:flex
          left-[calc(300px+max(0px,(100vw-300px-1600px)/2)+2rem)] right-[calc(max(0px,(100vw-300px-1600px)/2)+2rem)]">
          <p className={cn("min-w-0 flex-1 truncate text-[17px] font-semibold transition-all duration-300",
            inlineTitle ? "translate-y-0 opacity-100" : "translate-y-1 opacity-0")} aria-hidden={!inlineTitle}>
            {title}
          </p>
          <button onClick={() => setSearch(true)}
            className="flex h-10 w-72 shrink-0 cursor-pointer items-center gap-2 rounded-full bg-field pl-3.5 pr-2 text-[15px] text-muted-foreground transition-colors hover:bg-field-hover">
            <Search className="size-[18px]" />
            <span className="flex-1 text-left">{tr("Поиск")}</span>
            <ShortcutHint />
          </button>
          {canCheckIn && !isActive("/reception") ? (
            <Button variant="secondary" asChild className="h-10"><Link href="/reception"><ScanLine /> {tr("Отметить визит")}</Link></Button>
          ) : null}
          {canAddClient ? (
            <Button asChild className="h-10"><Link href="/clients?new=1"><Plus /> {tr("Клиент")}</Link></Button>
          ) : null}
        </div>

        <CommandMenu open={search} onOpenChange={setSearch} gymId={gymId} sections={items} readOnly={readOnly} />
      </div>
    </NavTitleContext.Provider>
  );
}

/** Подсказка сочетания: «⌘K» на Mac и iPad с клавиатурой, «Ctrl K» на остальных; на сенсорных экранах без мыши скрыта */
function ShortcutHint() {
  const apple = useSyncExternalStore(noSubscribe, () => /Mac|iPhone|iPad|iPod/.test(navigator.userAgent), () => false);
  return <span className="[@media(pointer:coarse)]:hidden"><Kbd>{apple ? "⌘K" : "Ctrl K"}</Kbd></span>;
}

function ThemeToggle() {
  const tr = useT();
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
    <button onClick={toggle} className="grid size-9 cursor-pointer place-items-center rounded-full text-tint-text hover:bg-field-hover active:opacity-60" aria-label={tr("Сменить тему")} title={tr("Сменить тему")}>
      <Sun className="hidden size-[18px] dark:block" />
      <Moon className="size-[18px] dark:hidden" />
    </button>
  );
}

/** Крупный заголовок iOS (34 pt): при прокрутке уходит, и компактная версия появляется в навигационной панели */
export function PageHeader({ title, description, actions, back }: {
  title: React.ReactNode; description?: React.ReactNode; actions?: React.ReactNode; back?: { href: string; label: string };
}) {
  const nav = useContext(NavTitleContext);
  const ref = useRef<HTMLHeadingElement>(null);
  const tr = useT();
  const tx = useTx();
  title = tx(title);
  description = tx(description);
  const text = typeof title === "string" ? title : null;

  useEffect(() => {
    if (!nav) return;
    nav.setTitle(text);
    const el = ref.current;
    if (!el) return;
    // панель занимает ~76px сверху: заголовок считается ушедшим, когда скрылся под ней
    const io = new IntersectionObserver(([e]) => nav.setCollapsed(!e.isIntersecting), { rootMargin: "-76px 0px 0px 0px" });
    io.observe(el);
    return () => {
      io.disconnect();
      nav.setCollapsed(false);
      nav.setTitle(null);
    };
  }, [nav, text]);

  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-x-6 gap-y-4">
      <div className="grid min-w-[min(100%,18rem)] flex-1 gap-1">
        {back ? (
          <Link href={back.href} className="-ml-1.5 inline-flex w-fit items-center gap-0.5 text-[17px] text-tint-text active:opacity-60">
            <ChevronLeft className="size-6" strokeWidth={2.25} /> {tr(back.label)}
          </Link>
        ) : null}
        <h1 ref={ref} className="text-[34px] font-bold leading-[41px] tracking-[-0.02em]">{title}</h1>
        {description ? <p className="text-[15px] text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}
