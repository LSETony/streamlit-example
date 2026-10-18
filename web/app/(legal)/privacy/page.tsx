import type { Metadata } from "next";
import { LegalDocument } from "@/components/legal-document";
import { PRIVACY } from "@/lib/legal/documents";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Политика конфиденциальности") };
}

export default async function Page() {
  const t = await getT();
  return <LegalDocument doc={PRIVACY[t.locale === "ru" ? "ru" : "en"]} updatedLabel={t("Обновлено")} />;
}
