import Link from "next/link";
import { Logo } from "@/components/logo";
import { LanguageSwitch } from "@/components/language-switch";
import { getT } from "@/lib/i18n/server";

export default async function LegalLayout({ children }: LayoutProps<"/">) {
  const t = await getT();
  return (
    <div className="min-h-dvh bg-background">
      <header className="glass glass-rim sticky top-[max(0.75rem,env(safe-area-inset-top))] z-30 mx-3 mt-3 flex h-16 items-center justify-between gap-4 rounded-[22px] px-6">
        <Link href="/" aria-label="core."><Logo className="h-6" /></Link>
        <LanguageSwitch />
      </header>
      <main className="mx-auto w-full max-w-3xl px-5 py-12">{children}</main>
      <footer className="mx-auto flex w-full max-w-3xl flex-wrap gap-x-6 gap-y-2 px-5 pb-12 text-sm text-muted-foreground">
        <Link href="/terms" className="hover:text-foreground">{t("Условия использования")}</Link>
        <Link href="/privacy" className="hover:text-foreground">{t("Политика конфиденциальности")}</Link>
      </footer>
    </div>
  );
}
