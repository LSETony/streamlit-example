import type { Metadata } from "next";
import { CheckCircle2 } from "lucide-react";
import { Logo } from "@/components/logo";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Оплата") };
}

// Сюда ЮKassa возвращает клиента после оплаты по ссылке из кабинета
export default async function PayDonePage() {
  const t = await getT();
  return (
    <div className="grid min-h-dvh place-items-center px-6">
      <div className="grid max-w-sm justify-items-center gap-4 text-center">
        <Logo className="h-7" />
        <CheckCircle2 className="size-14 text-success" strokeWidth={1.5} />
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">{t("Спасибо! Оплата обрабатывается")}</h1>
        <p className="text-sm text-muted-foreground">
          {t("Абонемент активируется автоматически в течение минуты, чек придёт на телефон или email. Эту страницу можно закрыть.")}
        </p>
      </div>
    </div>
  );
}
