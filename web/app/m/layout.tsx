import type { Metadata, Viewport } from "next";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  const t = await getT();
  return {
    title: { absolute: t("core. — мой зал") },
    description: t("Пропуск в зал, абонементы и запись на занятия"),
    manifest: "/m/manifest",
    appleWebApp: { capable: true, title: "core.", statusBarStyle: "default" },
  };
}

export const viewport: Viewport = { themeColor: "#510bf5" };

export default function MemberLayout({ children }: LayoutProps<"/m">) {
  return <div className="mx-auto min-h-dvh w-full max-w-md bg-background">{children}</div>;
}
