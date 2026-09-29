"use client";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Search } from "lucide-react";
import { Input, NativeSelect } from "@/components/ui/input";
import { cn } from "@/lib/utils";

export function ClientFilters({ q, state, tag, risk, tags, showRisk }: {
  q: string; state: string; tag: string; risk: boolean; tags: string[]; showRisk: boolean;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [text, setText] = useState(q);

  const push = (patch: Record<string, string | null>) => {
    const params = new URLSearchParams();
    const next = { q: text, state, tag, risk: risk ? "1" : "", ...patch };
    Object.entries(next).forEach(([k, v]) => v && params.set(k, v));
    router.replace(`${pathname}?${params}`);
  };

  useEffect(() => {
    if (text === q) return;
    const t = setTimeout(() => push({ q: text }), 300);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text]);

  // Как в iOS: строка поиска, под ней — ряд фильтров-капсул, который на телефоне прокручивается вбок
  return (
    <div className="mb-4 flex flex-col gap-2.5 lg:flex-row lg:items-center">
      <div className="relative flex-1">
        <Search className="pointer-events-none absolute left-3 top-1/2 size-[18px] -translate-y-1/2 text-muted-foreground" />
        <Input type="search" value={text} onChange={(e) => setText(e.target.value)} placeholder="Поиск по ФИО или телефону" className="h-10 pl-10" />
      </div>
      <div className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-0.5 [scrollbar-width:none] sm:mx-0 sm:px-0">
        <NativeSelect value={state} onChange={(e) => push({ state: e.target.value })} aria-label="Статус абонемента"
          className={cn(pill, "w-auto", state && pillOn)}>
          <option value="">Все абонементы</option>
          <option value="active">Действует</option>
          <option value="frozen">Заморожен</option>
          <option value="future">Начнётся позже</option>
          <option value="expired">Закончился</option>
          <option value="none">Без абонемента</option>
        </NativeSelect>
        {tags.length ? (
          <NativeSelect value={tag} onChange={(e) => push({ tag: e.target.value })} aria-label="Тег" className={cn(pill, "w-auto", tag && pillOn)}>
            <option value="">Все теги</option>
            {tags.map((t) => <option key={t} value={t}>{t}</option>)}
          </NativeSelect>
        ) : null}
        {showRisk ? (
          <button
            type="button"
            onClick={() => push({ risk: risk ? null : "1" })}
            className={cn("h-9 shrink-0 cursor-pointer whitespace-nowrap rounded-full px-4 text-[15px] font-medium transition-colors active:opacity-70",
              risk ? "bg-tint text-white" : "bg-field hover:bg-field-hover")}
            aria-pressed={risk}
          >
            В зоне риска
          </button>
        ) : null}
      </div>
    </div>
  );
}

const pill = "h-9 shrink-0 rounded-full pl-4 pr-9 text-[15px] font-medium [background-position:right_12px_center]";
const pillOn = "bg-tint-soft text-tint-text hover:bg-tint-soft";
