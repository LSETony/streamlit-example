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

/** Поиск клиента по ФИО или телефону (FR-2.1, FR-4.3) */
export function ClientSearch({ gymId, onSelect, autoFocus, placeholder = "ФИО или телефон", className, size = "default" }: {
  gymId: string; onSelect: (c: ClientRow) => void; autoFocus?: boolean; placeholder?: string; className?: string; size?: "default" | "lg";
}) {
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
      <Search className={cn("pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground", size === "lg" ? "size-5" : "size-4")} />
      <Input
        value={q}
        onChange={(e) => setQ(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown") { e.preventDefault(); setActive((a) => Math.min(a + 1, items.length - 1)); }
          if (e.key === "ArrowUp") { e.preventDefault(); setActive((a) => Math.max(a - 1, 0)); }
          if (e.key === "Enter" && items[active]) { e.preventDefault(); pick(items[active]); }
          if (e.key === "Escape") setItems([]);
        }}
        autoFocus={autoFocus}
        placeholder={placeholder}
        className={cn(size === "lg" ? "h-14 rounded-xl pl-11 text-lg" : "pl-9")}
        role="combobox"
        aria-expanded={items.length > 0}
        aria-autocomplete="list"
      />
      {q.trim().length >= 2 && (items.length > 0 || !loading) ? (
        <div className="absolute inset-x-0 top-full z-30 mt-1 overflow-hidden rounded-xl border border-border bg-card shadow-lg" role="listbox">
          {items.length === 0 ? (
            <p className="px-4 py-3 text-sm text-muted-foreground">Никого не нашли</p>
          ) : items.map((c, i) => (
            <button
              key={c.id}
              type="button"
              role="option"
              aria-selected={i === active}
              onMouseEnter={() => setActive(i)}
              onClick={() => pick(c)}
              className={cn("flex w-full cursor-pointer items-center gap-3 px-3 py-2.5 text-left", i === active && "bg-muted")}
            >
              <Avatar name={c.full_name} className="size-9 text-xs" />
              <span className="min-w-0 flex-1">
                <span className="flex items-center gap-1.5 truncate font-medium">
                  {c.full_name}
                  {c.in_app ? <Smartphone className="size-3.5 text-muted-foreground" aria-label="В приложении" /> : null}
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
