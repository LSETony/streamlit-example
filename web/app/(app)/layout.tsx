import { AppShell } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { date } from "@/lib/format";
import { redirect } from "next/navigation";

export default async function AppLayout({ children }: LayoutProps<"/">) {
  const ctx = await requireStaff();
  if (!ctx.gym.onboarded_at && ctx.staff.role === "owner") redirect("/onboarding");
  const supabase = await createClient();
  const { count } = ctx.features.risk === false
    ? { count: null }
    : await supabase.from("v_client_risk").select("client_id", { count: "exact", head: true }).eq("gym_id", ctx.gym.id).is("contacted_at", null);

  const banner = ctx.readOnly ? (
    <div className="border-b border-warning/40 bg-warning/15 px-4 py-2.5 text-center text-sm">
      Пробный период закончился {date(ctx.gym.trial_until)}. Кабинет работает в режиме «только чтение» — данные сохранены.
      Чтобы продолжить работу, свяжитесь с командой core.
    </div>
  ) : null;

  return (
    <AppShell role={ctx.staff.role} features={ctx.features} gymName={ctx.gym.name} userName={ctx.staff.full_name}
      riskCount={count ?? null} banner={banner}>
      {children}
    </AppShell>
  );
}
