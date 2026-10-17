import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Демо") };
}

/** Публичное демо: вход в один клик в демо-зал России или ОАЭ, только просмотр */
export default async function DemoPage({ searchParams }: PageProps<"/demo">) {
  const t = await getT();
  const failed = (await searchParams).error;
  return (
    <div className="grid gap-6">
      <div className="grid gap-2">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">{t("Попробуйте core. без регистрации")}</h1>
        <p className="text-[15px] text-muted-foreground">{t("Демо-зал с данными за 10 месяцев. Всё можно смотреть, изменения отключены.")}</p>
      </div>
      <div className="grid gap-3">
        <DemoLink href="/demo/ae" title={t("Зал в ОАЭ")} hint={t("Английский · AED · +971")} />
        <DemoLink href="/demo/ru" title={t("Зал в России")} hint={t("Русский · ₽ · +7")} />
      </div>
      {failed ? <p className="text-sm text-destructive">{t("Не удалось открыть демо. Попробуйте ещё раз через минуту.")}</p> : null}
      <p className="text-center text-sm text-muted-foreground">
        {t("Готовы подключить свой зал?")} <Link href="/signup" className="font-medium text-tint-text">{t("Подключить зал")}</Link>
      </p>
    </div>
  );
}

function DemoLink({ href, title, hint }: { href: string; title: string; hint: string }) {
  return (
    // обычная ссылка, не <Link>: маршрут ставит cookies сессии и перенаправляет
    <a href={href} className="flex items-center justify-between gap-4 rounded-[22px] bg-field p-5 transition-colors hover:bg-tint-soft active:scale-[0.99]">
      <span className="grid gap-1">
        <span className="text-[19px] font-semibold">{title}</span>
        <span className="text-sm text-muted-foreground">{hint}</span>
      </span>
      <ArrowRight className="size-5 shrink-0 text-tint-text" />
    </a>
  );
}
