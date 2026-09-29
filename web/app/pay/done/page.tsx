import type { Metadata } from "next";
import { CheckCircle2 } from "lucide-react";
import { Logo } from "@/components/logo";

export const metadata: Metadata = { title: "Оплата" };

// Сюда ЮKassa возвращает клиента после оплаты по ссылке из кабинета
export default function PayDonePage() {
  return (
    <div className="grid min-h-dvh place-items-center px-6">
      <div className="grid max-w-sm justify-items-center gap-4 text-center">
        <Logo className="h-7" />
        <CheckCircle2 className="size-14 text-success" strokeWidth={1.5} />
        <h1 className="text-2xl font-bold tracking-tight">Спасибо! Оплата обрабатывается</h1>
        <p className="text-sm text-muted-foreground">
          Абонемент активируется автоматически в течение минуты, чек придёт на телефон или email. Эту страницу можно закрыть.
        </p>
      </div>
    </div>
  );
}
