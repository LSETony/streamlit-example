"use server";
import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { isPlatformAdmin } from "@/lib/auth";
import { str, strOrNull } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";

async function requirePlatform() {
  if (!(await isPlatformAdmin())) throw new Error("Только для команды core.");
}

/** FR-10: команда core. создаёт зал и приглашает владельца */
export async function adminCreateGym(form: FormData): Promise<ActionResult<null>> {
  await requirePlatform();
  const name = str(form, "name");
  const email = str(form, "owner_email").toLowerCase();
  const ownerName = str(form, "owner_name");
  if (!name || !email || !ownerName) return { ok: false, error: { code: "INVALID_INPUT", message: "Заполните все поля" } };
  const admin = createAdminClient();
  const h = await headers();
  const origin = process.env.PUBLIC_APP_URL ?? `${h.get("x-forwarded-proto") ?? "http"}://${h.get("host")}`;
  let userId: string | null = null;
  const invite = await admin.auth.admin.inviteUserByEmail(email, { redirectTo: `${origin}/auth/callback?next=/reset-password` });
  if (invite.data.user) userId = invite.data.user.id;
  else {
    const { data } = await admin.rpc("admin_find_user", { p_email: email });
    userId = (data as string | null) ?? null;
    if (!userId) return fail(invite.error);
  }
  const trialDays = Number(str(form, "trial_days")) || 14;
  const trialUntil = new Date(Date.now() + trialDays * 86400000).toISOString().slice(0, 10);
  const region = str(form, "region") === "AE" ? "AE" : "RU";
  const tz = str(form, "timezone");
  const { data: gym, error } = await admin.from("gyms").insert({
    name, address: strOrNull(form, "address"), region,
    // пояс должен соответствовать региону: для ОАЭ — Дубай
    timezone: region === "AE" ? "Asia/Dubai" : tz && tz !== "Asia/Dubai" ? tz : "Europe/Moscow",
    core_plan: str(form, "core_plan") || "start", trial_until: trialUntil,
  }).select("id").single();
  if (error) return fail(error);
  const { error: e2 } = await admin.from("staff").insert({ gym_id: gym.id, user_id: userId, email, role: "owner", full_name: ownerName });
  if (e2) return fail(e2);
  revalidatePath("/admin");
  return ok(null);
}

export async function adminUpdateGym(input: {
  gymId: string; corePlan: "start" | "business" | "network"; trialUntil: string; paidUntil: string | null; features: Record<string, boolean>;
}): Promise<ActionResult<null>> {
  const supabase = await createClient();
  const { error } = await supabase.rpc("admin_update_gym", {
    p_gym: input.gymId, p_core_plan: input.corePlan, p_trial_until: input.trialUntil,
    p_paid_until: input.paidUntil, p_features: input.features, p_clear_paid: !input.paidUntil,
  });
  if (error) return fail(error);
  revalidatePath("/admin");
  return ok(null);
}
