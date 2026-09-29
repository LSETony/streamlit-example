"use client";
import { useRouter } from "next/navigation";
import { NativeSelect } from "@/components/ui/input";
import { DateRangePicker } from "@/components/ui/date-picker";

/** Период дашборда: по умолчанию текущий месяц; «Свой период» — диапазон в календаре, применяется сразу */
export function PeriodPicker({ current, from, to }: { current: string; from: string; to: string }) {
  const router = useRouter();
  const custom = (f: string, t: string) => router.push(`/dashboard?p=custom&from=${f}&to=${t}`);
  return (
    <div className="flex flex-wrap items-center gap-2">
      <NativeSelect value={current} onChange={(e) => e.target.value !== "custom" ? router.push(`/dashboard?p=${e.target.value}`) : custom(from, to)} className="w-44" aria-label="Период">
        <option value="month">Этот месяц</option>
        <option value="prev_month">Прошлый месяц</option>
        <option value="7d">7 дней</option>
        <option value="30d">30 дней</option>
        <option value="custom">Свой период</option>
      </NativeSelect>
      {current === "custom" ? <DateRangePicker from={from} to={to} onChange={custom} aria-label="Свой период" /> : null}
    </div>
  );
}
