import type { Metadata } from "next";
import { LegalDocument } from "@/components/legal-document";
import { TERMS } from "@/lib/legal/documents";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Условия использования") };
}

export default async function Page() {
  const t = await getT();
  return <LegalDocument doc={TERMS[t.locale]} updatedLabel={t("Обновлено")} />;
}
