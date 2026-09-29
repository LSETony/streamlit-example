"use client";
import { usePathname, useRouter } from "next/navigation";
import { Input, NativeSelect } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { addDays } from "@/lib/format";

export function PaymentFilters({ from, to, method, status, today }: { from: string; to: string; method: string; status: string; today: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const go = (patch: Record<string, string>) => {
    const p = new URLSearchParams({ from, to, method, status, ...patch });
    [...p.keys()].forEach((k) => !p.get(k) && p.delete(k));
    router.replace(`${pathname}?${p}`);
  };
  const monthStart = today.slice(0, 8) + "01";
  return (
    <div className="mb-4 flex flex-wrap items-center gap-2">
      <div className="flex rounded-full bg-field p-1">
        {([["Сегодня", today, today], ["Вчера", addDays(today, -1), addDays(today, -1)], ["Этот месяц", monthStart, today]] as const).map(([label, f, t]) => (
          <button key={label} type="button" onClick={() => go({ from: f, to: t })} aria-pressed={from === f && to === t}
            className={cn("h-8 cursor-pointer rounded-full px-4 text-sm font-medium transition-colors", from === f && to === t ? "bg-foreground text-background" : "text-muted-foreground hover:text-foreground")}>
            {label}
          </button>
        ))}
      </div>
      <Input type="date" value={from} onChange={(e) => go({ from: e.target.value })} className="h-10 w-40 rounded-full" aria-label="С" />
      <Input type="date" value={to} onChange={(e) => go({ to: e.target.value })} className="h-10 w-40 rounded-full" aria-label="По" />
      <NativeSelect value={method} onChange={(e) => go({ method: e.target.value })} className="h-10 w-40 rounded-full" aria-label="Способ">
        <option value="">Все способы</option><option value="cash">Наличные</option><option value="card">Карта</option><option value="online">Онлайн</option>
      </NativeSelect>
      <NativeSelect value={status} onChange={(e) => go({ status: e.target.value })} className="h-10 w-40 rounded-full" aria-label="Статус">
        <option value="">Все статусы</option><option value="succeeded">Оплачено</option><option value="pending">Ожидает</option>
        <option value="failed">Не прошла</option><option value="refunds">Возвраты</option>
      </NativeSelect>
    </div>
  );
}
