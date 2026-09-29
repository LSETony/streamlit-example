import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Logo } from "@/components/logo";
import { getStaffContext, getUser, homeFor } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { Plan } from "@/lib/types";
import { Wizard } from "./wizard";

export const metadata: Metadata = { title: "Настройка зала" };

/** FR-1.2 Мастер первой настройки: зал, часы, зоны, тарифы, сотрудники */
export default async function OnboardingPage({ searchParams }: PageProps<"/onboarding">) {
  const user = await getUser();
  if (!user) redirect("/login");
  const ctx = await getStaffContext();
  if (ctx && (ctx.gym.onboarded_at || ctx.staff.role !== "owner")) redirect(homeFor(ctx.staff.role));
  const sp = await searchParams;
  const step = ctx ? Math.min(5, Math.max(1, Number(sp.step) || 1)) : 0;

  let zones: { id: string; name: string; capacity: number }[] = [];
  let plans: Plan[] = [];
  let staff: { id: string; full_name: string; email: string; role: string }[] = [];
  if (ctx) {
    const supabase = await createClient();
    const [z, p, s] = await Promise.all([
      supabase.from("zones").select("id, name, capacity").eq("gym_id", ctx.gym.id).order("name"),
      supabase.from("membership_plans").select("*").eq("gym_id", ctx.gym.id).order("price"),
      supabase.from("staff").select("id, full_name, email, role").eq("gym_id", ctx.gym.id).order("created_at"),
    ]);
    zones = z.data ?? [];
    plans = (p.data ?? []) as Plan[];
    staff = s.data ?? [];
  }

  return (
    <div className="min-h-dvh bg-background">
      <header className="flex h-16 items-center border-b border-border bg-card px-6"><Logo className="h-7" /></header>
      <main className="mx-auto w-full max-w-3xl px-4 py-10">
        <Wizard step={step} gym={ctx?.gym ?? null} zones={zones} plans={plans} staff={staff} email={user.email ?? ""} />
      </main>
    </div>
  );
}
