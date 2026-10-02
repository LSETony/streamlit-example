import { AppShell } from "@/components/app-shell";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { date } from "@/lib/format";
import { redirect } from "next/navigation";
import { getT } from "@/lib/i18n/server";

export default async function AppLayout({ children }: LayoutProps<"/">) {
  const ctx = await requireStaff();
  const t = await getT();
  if (!ctx.gym.onboarded_at && ctx.staff.role === "owner") redirect("/onboarding");
  const supabase = await createClient();
  const { count } = ctx.features.risk === false
    ? { count: null }
    : await supabase.from("v_client_risk").select("client_id", { count: "exact", head: true }).eq("gym_id", ctx.gym.id).is("contacted_at", null);

  const banner = ctx.readOnly ? (
    <div className="mx-4 mt-3 rounded-2xl border border-warning/40 bg-warning/15 px-4 py-2.5 text-center text-sm backdrop-blur-xl sm:mx-6 lg:mx-8">
      {t("Пробный период закончился {date}. Кабинет работает в режиме «только чтение» — данные сохранены. Чтобы продолжить работу, свяжитесь с командой core.", { date: date(ctx.gym.trial_until) })}
    </div>
  ) : null;

  return (
    <AppShell role={ctx.staff.role} features={ctx.features} gymId={ctx.gym.id} gymName={ctx.gym.name} readOnly={ctx.readOnly} userName={ctx.staff.full_name}
      riskCount={count ?? null} banner={banner}>
      {children}
    </AppShell>
  );
}
