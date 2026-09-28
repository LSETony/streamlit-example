import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Gym, Role } from "@/lib/types";
import { todayIn } from "@/lib/format";

export interface StaffContext {
  userId: string;
  email: string | null;
  staff: { id: string; role: Role; full_name: string };
  gym: Gym;
  features: Record<string, boolean>;
  readOnly: boolean;
  today: string;
  isPlatformAdmin: boolean;
}

export const getUser = cache(async () => {
  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  return data.user ?? null;
});

export const isPlatformAdmin = cache(async (): Promise<boolean> => {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_list_gyms").limit(1);
  return !error;
});

// Контекст сотрудника: зал, роль, флаги функций, режим «только чтение»
export const getStaffContext = cache(async (): Promise<StaffContext | null> => {
  const user = await getUser();
  if (!user) return null;
  const supabase = await createClient();
  const { data: staff } = await supabase
    .from("staff")
    .select("id, role, full_name, gym_id, gyms(*)")
    .eq("user_id", user.id)
    .eq("active", true)
    .order("created_at")
    .limit(1)
    .maybeSingle();
  if (!staff || !staff.gyms) return null;
  const gym = staff.gyms as unknown as Gym;
  const { data: features } = await supabase.rpc("gym_features", { p_gym: gym.id });
  const today = todayIn(gym.timezone);
  const readOnly = gym.trial_until < today && (!gym.paid_until || gym.paid_until < today);
  return {
    userId: user.id,
    email: user.email ?? null,
    staff: { id: staff.id, role: staff.role as Role, full_name: staff.full_name },
    gym,
    features: (features ?? {}) as Record<string, boolean>,
    readOnly,
    today,
    isPlatformAdmin: false,
  };
});

/** Требует вошедшего сотрудника (и одну из ролей). Иначе — на вход, в мастер настройки или на доступный раздел. */
export async function requireStaff(roles?: Role[]): Promise<StaffContext> {
  const user = await getUser();
  if (!user) redirect("/login");
  const ctx = await getStaffContext();
  if (!ctx) {
    if (await isPlatformAdmin()) redirect("/admin");
    redirect("/onboarding");
  }
  if (roles && !roles.includes(ctx.staff.role)) redirect(homeFor(ctx.staff.role));
  return ctx;
}

export function homeFor(role: Role): string {
  return role === "reception" ? "/reception" : "/dashboard";
}
