import type { Metadata } from "next";
import { PageHeader } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { Plan } from "@/lib/types";
import { PlansManager } from "./plans-manager";

export const metadata: Metadata = { title: "Тарифы" };

export default async function PlansPage() {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const { data } = await supabase.from("membership_plans").select("*").eq("gym_id", ctx.gym.id).order("active", { ascending: false }).order("price");
  return (
    <>
      <PageHeader title="Тарифы" description="Цена фиксируется в момент продажи — изменение тарифа не меняет уже проданные абонементы." />
      <PlansManager plans={(data ?? []) as Plan[]} readOnly={ctx.readOnly} />
    </>
  );
}
