"use client";
import { usePathname, useRouter } from "next/navigation";
import { NativeSelect } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { Segmented, segmentClass } from "@/components/ui/tabs";
import { addDays } from "@/lib/format";
import { DateRangePicker } from "@/components/ui/date-picker";

const pill = "h-9 shrink-0 rounded-full text-[15px] font-medium";
const pillOn = "bg-tint-soft text-tint-text hover:bg-tint-soft";

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
    <div className="mb-4 flex flex-col gap-2.5 lg:flex-row lg:items-center">
      <Segmented className="self-start">
        {([["Сегодня", today, today], ["Вчера", addDays(today, -1), addDays(today, -1)], ["Этот месяц", monthStart, today]] as const).map(([label, f, t]) => (
          <button key={label} type="button" onClick={() => go({ from: f, to: t })} aria-pressed={from === f && to === t} className={segmentClass}>
            {label}
          </button>
        ))}
      </Segmented>
      <div className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-0.5 [scrollbar-width:none] sm:mx-0 sm:px-0">
        <DateRangePicker from={from} to={to} max={today} onChange={(f, t) => go({ from: f, to: t })} className={cn(pill, "shrink-0 px-4")} aria-label="Период" />
        <NativeSelect value={method} onChange={(e) => go({ method: e.target.value })} className={cn(pill, "w-auto px-4", method && pillOn)} aria-label="Способ">
          <option value="">Все способы</option><option value="cash">Наличные</option><option value="card">Карта</option><option value="online">Онлайн</option>
        </NativeSelect>
        <NativeSelect value={status} onChange={(e) => go({ status: e.target.value })} className={cn(pill, "w-auto px-4", status && pillOn)} aria-label="Статус">
          <option value="">Все статусы</option><option value="succeeded">Оплачено</option><option value="pending">Ожидает</option>
          <option value="failed">Не прошла</option><option value="refunds">Возвраты</option>
        </NativeSelect>
      </div>
    </div>
  );
}
