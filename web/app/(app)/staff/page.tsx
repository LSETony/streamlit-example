import type { Metadata } from "next";
import { PageHeader } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { Role } from "@/lib/types";
import { StaffManager } from "./staff-manager";

export const metadata: Metadata = { title: "Сотрудники" };

export default async function StaffPage() {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const { data } = await supabase.from("staff").select("id, email, role, full_name, active, user_id, created_at").eq("gym_id", ctx.gym.id).order("active", { ascending: false }).order("created_at");
  return (
    <>
      <PageHeader title="Сотрудники" description="Приглашение по email. Отключённый сотрудник теряет доступ, история его действий сохраняется." />
      <StaffManager staff={(data ?? []) as { id: string; email: string; role: Role; full_name: string; active: boolean; user_id: string | null }[]} meId={ctx.staff.id} readOnly={ctx.readOnly} />
    </>
  );
}
