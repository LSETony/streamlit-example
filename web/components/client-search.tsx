"use client";
import { useEffect, useRef, useState } from "react";
import { Search, Smartphone } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Avatar } from "@/components/ui/misc";
import { MembershipStateBadge } from "@/components/status";
import { createClient } from "@/lib/supabase/client";
import { phone as fmtPhone } from "@/lib/format";
import type { ClientRow } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useT } from "@/lib/i18n/client";

/** Поиск клиента по ФИО или телефону (FR-2.1, FR-4.3) */
export function ClientSearch({ gymId, onSelect, autoFocus, placeholder = "ФИО или телефон", className, size = "default", inline, onQueryChange }: {
  gymId: string; onSelect: (c: ClientRow) => void; autoFocus?: boolean; placeholder?: string; className?: string; size?: "default" | "lg";
  /** результаты списком под полем (внутри диалога), а не всплывающим окном */
  inline?: boolean;
  onQueryChange?: (q: string) => void;
}) {
  const t = useT();
  const [q, setQ] = useState("");
  const [items, setItems] = useState<ClientRow[]>([]);
  const [active, setActive] = useState(0);
  const [loading, setLoading] = useState(false);
  const seq = useRef(0);

  useEffect(() => {
    const term = q.trim();
    if (term.length < 2) return;
    const my = ++seq.current;
    const t = setTimeout(async () => {
      setLoading(true);
      const digits = term.replace(/\D/g, "");
      let query = createClient().from("v_clients").select("*").eq("gym_id", gymId).limit(8);
      if (digits.length >= 3 && digits.length >= term.replace(/\s/g, "").length - 2) {
        const tail = digits.length >= 10 ? digits.slice(-10) : digits.replace(/^[78]/, "");
        query = query.like("phone", `%${tail}%`);
      } else {
        query = query.ilike("full_name", `%${term.replace(/[%_]/g, "")}%`);
      }
      const { data } = await query.order("full_name");
      if (my === seq.current) {
        setItems((data ?? []) as ClientRow[]);
        setActive(0);
        setLoading(false);
      }
    }, 180);
    return () => clearTimeout(t);
  }, [q, gymId]);

  const pick = (c: ClientRow) => {
    onSelect(c);
    setQ("");
    setItems([]);
  };

  return (
    <div className={cn("relative", className)}>
      <div className="relative">
        <Search className={cn("pointer-events-none absolute top-1/2 -translate-y-1/2 text-muted-foreground", size === "lg" ? "left-4 size-5" : "left-3.5 size-4")} />
        <Input
          value={q}
          onChange={(e) => { setQ(e.target.value); onQueryChange?.(e.target.value); }}
          onKeyDown={(e) => {
            if (e.key === "ArrowDown") { e.preventDefault(); setActive((a) => Math.min(a + 1, items.length - 1)); }
            if (e.key === "ArrowUp") { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)); }
            if (e.key === "Enter" && items[active]) { e.preventDefault(); pick(items[active]); }
            if (e.key === "Escape") setItems([]);
          }}
          autoFocus={autoFocus}
          placeholder={placeholder}
          className={cn(size === "lg" ? "h-14 pl-12 text-lg" : "pl-10")}
          role="combobox"
          aria-expanded={items.length > 0}
          aria-autocomplete="list"
        />
      </div>
      {q.trim().length >= 2 && (items.length > 0 || !loading) ? (
        <div className={cn(inline ? "mt-2 grid gap-0.5" : "glass-strong glass-rim absolute inset-x-0 top-full z-30 mt-2 overflow-hidden rounded-2xl p-1.5")} role="listbox">
          {items.length === 0 ? (
            <p className="px-4 py-3 text-sm text-muted-foreground">{t("Никого не нашли")}</p>
          ) : items.map((c, i) => (
            <button
              key={c.id}
              type="button"
              role="option"
              aria-selected={i === active}
              onMouseEnter={() => setActive(i)}
              onClick={() => pick(c)}
              className={cn("flex w-full cursor-pointer items-center gap-3 rounded-xl px-3 py-2.5 text-left", i === active && "bg-field-hover")}
            >
              <Avatar name={c.full_name} className="size-9 text-xs" />
              <span className="min-w-0 flex-1">
                <span className="flex items-center gap-1.5 truncate font-medium">
                  {c.full_name}
                  {c.in_app ? <Smartphone className="size-3.5 text-muted-foreground" aria-label={t("В приложении")} /> : null}
                </span>
                <span className="block text-xs text-muted-foreground tabular">{fmtPhone(c.phone)}</span>
              </span>
              <MembershipStateBadge state={c.membership_state} endsOn={c.membership_ends_on} />
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
