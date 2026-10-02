"use client";
import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { setLocale } from "@/app/actions/locale";
import { useT } from "@/lib/i18n/client";
import { cn } from "@/lib/utils";
import type { Locale } from "@/lib/i18n/core";

/** Переключатель языка RU / EN — сегментированный, как в iOS */
export function LanguageSwitch({ className }: { className?: string }) {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const pick = (l: Locale) => {
    if (l === t.locale) return;
    start(async () => {
      await setLocale(l);
      document.documentElement.lang = l;
      router.refresh();
    });
  };
  return (
    <div role="group" aria-label={t("Язык")} className={cn("inline-flex h-8 shrink-0 items-center rounded-full bg-field p-[3px]", pending && "opacity-60", className)}>
      {(["ru", "en"] as const).map((l) => (
        <button key={l} type="button" onClick={() => pick(l)} aria-pressed={t.locale === l} lang={l}
          className={cn("h-full cursor-pointer rounded-full px-2.5 text-[12px] font-semibold uppercase transition-colors",
            t.locale === l ? "bg-[var(--segment-thumb)] text-foreground shadow-[0_2px_6px_rgb(0_0_0/0.12)]" : "text-muted-foreground hover:text-foreground")}>
          {l}
        </button>
      ))}
    </div>
  );
}
