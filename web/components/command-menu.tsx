"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { CalendarPlus, ScanLine, UserPlus, CornerDownLeft } from "lucide-react";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { ClientSearch } from "@/components/client-search";

export interface CommandSection {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}

/** Быстрый поиск (Ctrl/⌘+K): клиент по ФИО или телефону, частые действия и переход в любой раздел */
export function CommandMenu({ open, onOpenChange, gymId, sections, readOnly }: {
  open: boolean; onOpenChange: (v: boolean) => void; gymId: string; sections: CommandSection[]; readOnly: boolean;
}) {
  const router = useRouter();
  const [q, setQ] = useState("");
  const go = (href: string) => {
    onOpenChange(false);
    setQ("");
    router.push(href);
  };
  const has = (href: string) => sections.some((s) => s.href === href);
  const actions = [
    !readOnly && has("/clients") ? { href: "/clients?new=1", label: "Новый клиент", hint: "Добавить за 30 секунд", icon: UserPlus } : null,
    has("/reception") ? { href: "/reception", label: "Отметить визит", hint: "Сканер QR и ручная отметка", icon: ScanLine } : null,
    has("/schedule") ? { href: "/schedule", label: "Записать на занятие", hint: "Расписание на неделю", icon: CalendarPlus } : null,
  ].filter((a) => a !== null);
  const term = q.trim().toLowerCase();
  const matched = term ? sections.filter((s) => s.label.toLowerCase().includes(term)) : sections;

  return (
    <Dialog open={open} onOpenChange={(v) => { onOpenChange(v); if (!v) setQ(""); }}>
      <DialogContent hideClose className="top-[8dvh] max-w-xl translate-y-0 gap-4 p-3 sm:top-[12dvh]">
        <DialogTitle className="sr-only">Быстрый поиск</DialogTitle>
        <ClientSearch
          gymId={gymId}
          size="lg"
          inline
          autoFocus
          placeholder="Найти клиента или раздел"
          onQueryChange={setQ}
          onSelect={(c) => go(`/clients/${c.id}`)}
        />
        {!term && actions.length ? (
          <div className="grid gap-2 sm:grid-cols-3">
            {actions.map((a) => (
              <button key={a.href} type="button" onClick={() => go(a.href)}
                className="group flex cursor-pointer flex-col items-start gap-3 rounded-[20px] bg-field p-3.5 text-left transition-colors hover:bg-field-hover">
                <span className="grid size-9 place-items-center rounded-[12px] bg-[linear-gradient(135deg,#f92c00,#b0179a_55%,#5900ff)] text-white shadow-[inset_0_1px_0_rgb(255_255_255/0.3)]">
                  <a.icon className="size-[18px]" />
                </span>
                <span className="grid gap-0.5">
                  <span className="text-sm font-semibold">{a.label}</span>
                  <span className="text-xs text-muted-foreground">{a.hint}</span>
                </span>
              </button>
            ))}
          </div>
        ) : null}
        {matched.length ? (
          <div className="grid gap-0.5">
            <p className="px-3 pb-1 text-[11px] font-medium uppercase tracking-[0.08em] text-muted-foreground">Разделы</p>
            {matched.map((s) => (
              <button key={s.href} type="button" onClick={() => go(s.href)}
                className="group flex cursor-pointer items-center gap-3 rounded-xl px-3 py-2 text-left text-sm hover:bg-field-hover">
                <s.icon className="size-4 text-muted-foreground" />
                <span className="flex-1">{s.label}</span>
                <CornerDownLeft className="size-3.5 text-muted-foreground opacity-0 group-hover:opacity-100" />
              </button>
            ))}
          </div>
        ) : null}
        <p className="hidden items-center justify-end gap-3 px-2 text-[11px] text-muted-foreground sm:flex">
          <span><Kbd>↑</Kbd> <Kbd>↓</Kbd> выбор</span>
          <span><Kbd>Enter</Kbd> открыть</span>
          <span><Kbd>Esc</Kbd> закрыть</span>
        </p>
      </DialogContent>
    </Dialog>
  );
}

export function Kbd({ children }: { children: React.ReactNode }) {
  return <kbd className="rounded-md bg-field-hover px-1.5 py-0.5 font-sans text-[11px] font-medium text-muted-foreground">{children}</kbd>;
}
