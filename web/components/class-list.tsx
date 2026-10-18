"use client";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";
import { cn } from "@/lib/utils";

export interface ClassItem {
  id: string; title: string; trainer_name: string | null; zone: string | null; starts_at: string; ends_at: string;
  capacity: number; booked: number; my_booking_id: string | null;
}

/** Список занятий по дням — общий для приложения и виджета на сайте зала */
export function ClassList({ items, tz, busy, onAction, actionLabel }: {
  items: ClassItem[]; tz: string; busy?: string | null; onAction: (item: ClassItem) => void; actionLabel?: (item: ClassItem) => string;
}) {
  const t = useT();
  const day = (ts: string) => new Intl.DateTimeFormat(t.intl, { weekday: "long", day: "numeric", month: "long", timeZone: tz }).format(new Date(ts));
  const hm = (ts: string) => new Intl.DateTimeFormat(t.intl, { hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone: tz }).format(new Date(ts));
  const groups: { day: string; items: ClassItem[] }[] = [];
  for (const it of items) {
    const d = day(it.starts_at);
    if (groups.at(-1)?.day !== d) groups.push({ day: d, items: [] });
    groups.at(-1)!.items.push(it);
  }
  return (
    <div className="grid gap-5">
      {groups.map((g) => (
        <section key={g.day} className="grid gap-2">
          <h2 className="pl-1 text-[13px] font-semibold uppercase tracking-wide text-muted-foreground">{g.day}</h2>
          {g.items.map((it) => {
            const free = Math.max(0, it.capacity - it.booked);
            return (
              <div key={it.id} className="flex items-center gap-4 rounded-3xl bg-card p-4">
                <div className="w-14 shrink-0 text-center">
                  <p className="text-lg font-bold tabular">{hm(it.starts_at)}</p>
                  <p className="text-xs text-muted-foreground tabular">{hm(it.ends_at)}</p>
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate font-semibold">{it.title}</p>
                  <p className="truncate text-sm text-muted-foreground">{[it.trainer_name, it.zone].filter(Boolean).join(" · ")}</p>
                  <p className={cn("text-xs", free ? "text-muted-foreground" : "text-destructive")}>
                    {free ? t("Свободно мест: {n} из {total}", { n: free, total: it.capacity }) : t("Мест нет")}
                  </p>
                </div>
                <Button size="sm" variant={it.my_booking_id ? "outline" : "default"} disabled={busy === it.id || (!free && !it.my_booking_id)}
                  onClick={() => onAction(it)}>
                  {actionLabel ? actionLabel(it) : it.my_booking_id ? t("Отменить") : t("Записаться")}
                </Button>
              </div>
            );
          })}
        </section>
      ))}
    </div>
  );
}
