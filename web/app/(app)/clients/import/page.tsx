import type { Metadata } from "next";
import { PageHeader } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ImportWizard } from "./import-wizard";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Импорт клиентов") };
}

export default async function ImportPage() {
  const ctx = await requireStaff(["owner", "admin"]);
  const supabase = await createClient();
  const { data: plans } = await supabase.from("membership_plans").select("name").eq("gym_id", ctx.gym.id);
  return (
    <>
      <PageHeader title="Импорт из Excel или CSV" description="Клиенты и действующие абонементы. Повторный импорт обновляет клиентов, а не дублирует их." />
      <ImportWizard planNames={(plans ?? []).map((p) => p.name)} readOnly={ctx.readOnly} />
    </>
  );
}
