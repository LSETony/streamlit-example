import type { Metadata, Viewport } from "next";
import { Noto_Sans_Arabic, Onest } from "next/font/google";
import { Toaster } from "sonner";
import { I18nProvider } from "@/lib/i18n/client";
import { getLocale, getT } from "@/lib/i18n/server";
import { dirOf } from "@/lib/i18n/core";
import "./globals.css";

const onest = Onest({ variable: "--font-onest", subsets: ["latin", "cyrillic"] });
// арабский шрифт подключается только для глифов, которых нет в Onest
const arabic = Noto_Sans_Arabic({ variable: "--font-arabic", subsets: ["arabic"], preload: false });

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return {
  title: { default: t("core. — кабинет зала"), template: "%s · core." },
  description: t("Клиенты, абонементы, посещения, расписание и клиенты в зоне риска"),
  robots: { index: false, follow: false },
  // с экрана «Домой» на iPhone открывается на весь экран, статус-бар поверх содержимого
  appleWebApp: { capable: true, title: "core.", statusBarStyle: "black-translucent" },
  };
}

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  // содержимое под вырезом и полоской «домой», отступы задаются через env(safe-area-inset-*)
  viewportFit: "cover",
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f2f2f7" },
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
  ],
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const locale = await getLocale();
  return (
    <html lang={locale} dir={dirOf(locale)} className={`${onest.variable} ${arabic.variable} h-full antialiased`} suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `try{var t=localStorage.getItem('core-theme');if(t==='light'||t==='dark')document.documentElement.dataset.theme=t}catch(e){}`,
          }}
        />
      </head>
      <body className="min-h-full">
        <I18nProvider locale={locale}>{children}</I18nProvider>
        <Toaster position="top-center" richColors closeButton />
      </body>
    </html>
  );
}
