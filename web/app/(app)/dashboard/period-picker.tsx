"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Input, NativeSelect } from "@/components/ui/input";
import { Button } from "@/components/ui/button";

/** Период дашборда: по умолчанию текущий месяц */
export function PeriodPicker({ current, from, to }: { current: string; from: string; to: string }) {
  const router = useRouter();
  const [custom, setCustom] = useState({ from, to });
  return (
    <div className="flex flex-wrap items-center gap-2">
      <NativeSelect value={current} onChange={(e) => e.target.value !== "custom" ? router.push(`/dashboard?p=${e.target.value}`) : router.push(`/dashboard?p=custom&from=${custom.from}&to=${custom.to}`)} className="w-44" aria-label="Период">
        <option value="month">Этот месяц</option>
        <option value="prev_month">Прошлый месяц</option>
        <option value="7d">7 дней</option>
        <option value="30d">30 дней</option>
        <option value="custom">Свой период</option>
      </NativeSelect>
      {current === "custom" ? (
        <>
          <Input type="date" value={custom.from} onChange={(e) => setCustom((c) => ({ ...c, from: e.target.value }))} className="w-40" aria-label="С" />
          <Input type="date" value={custom.to} onChange={(e) => setCustom((c) => ({ ...c, to: e.target.value }))} className="w-40" aria-label="По" />
          <Button variant="outline" onClick={() => router.push(`/dashboard?p=custom&from=${custom.from}&to=${custom.to}`)}>Показать</Button>
        </>
      ) : null}
    </div>
  );
}
