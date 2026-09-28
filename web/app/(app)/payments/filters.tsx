"use client";
import { usePathname, useRouter } from "next/navigation";
import { Input, NativeSelect } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
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
      <Button variant={from === today && to === today ? "default" : "outline"} size="sm" onClick={() => go({ from: today, to: today })}>Сегодня</Button>
      <Button variant={from === addDays(today, -1) && to === addDays(today, -1) ? "default" : "outline"} size="sm" onClick={() => go({ from: addDays(today, -1), to: addDays(today, -1) })}>Вчера</Button>
      <Button variant={from === monthStart && to === today ? "default" : "outline"} size="sm" onClick={() => go({ from: monthStart, to: today })}>Этот месяц</Button>
      <Input type="date" value={from} onChange={(e) => go({ from: e.target.value })} className="h-8 w-40" aria-label="С" />
      <Input type="date" value={to} onChange={(e) => go({ to: e.target.value })} className="h-8 w-40" aria-label="По" />
      <NativeSelect value={method} onChange={(e) => go({ method: e.target.value })} className="h-8 w-36" aria-label="Способ">
        <option value="">Все способы</option><option value="cash">Наличные</option><option value="card">Карта</option><option value="online">Онлайн</option>
      </NativeSelect>
      <NativeSelect value={status} onChange={(e) => go({ status: e.target.value })} className="h-8 w-40" aria-label="Статус">
        <option value="">Все статусы</option><option value="succeeded">Оплачено</option><option value="pending">Ожидает</option>
        <option value="failed">Не прошла</option><option value="refunds">Возвраты</option>
      </NativeSelect>
    </div>
  );
}
