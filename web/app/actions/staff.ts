"use server";
import { revalidatePath } from "next/cache";
import { headers } from "next/headers";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { str } from "@/lib/actions";
import { fail, ok, type ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import type { Role } from "@/lib/types";

async function origin(): Promise<string> {
  const h = await headers();
  return process.env.PUBLIC_APP_URL ?? `${h.get("x-forwarded-proto") ?? "http"}://${h.get("host")}`;
}

/** FR-1.3 Приглашение сотрудника по email с ролью */
export async function inviteStaff(form: FormData): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  if (ctx.readOnly) return { ok: false, error: { code: "GYM_READ_ONLY", message: "Кабинет в режиме «только чтение»" } };
  const email = str(form, "email").toLowerCase();
  const fullName = str(form, "full_name");
  const role = str(form, "role") as Role;
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return { ok: false, error: { code: "INVALID_INPUT", message: "Некорректный email" } };
  if (!fullName) return { ok: false, error: { code: "INVALID_INPUT", message: "Укажите имя сотрудника" } };
  if (!["admin", "reception", "owner"].includes(role)) return { ok: false, error: { code: "INVALID_INPUT", message: "Выберите роль" } };

  const admin = createAdminClient();
  let userId: string | null = null;
  const invite = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: `${await origin()}/auth/callback?next=/reset-password`,
    data: { full_name: fullName },
  });
  if (invite.data.user) {
    userId = invite.data.user.id;
  } else {
    // пользователь уже есть (например, работает в другом зале) — находим по email
    const { data } = await admin.rpc("admin_find_user", { p_email: email });
    userId = (data as string | null) ?? null;
    if (!userId) return fail(invite.error ?? new Error("Не удалось отправить приглашение"));
  }

  // запись сотрудника делается от имени владельца — проверка прав через RLS
  const supabase = await createClient();
  const { error } = await supabase.from("staff").upsert(
    { gym_id: ctx.gym.id, user_id: userId, email, role, full_name: fullName, active: true },
    { onConflict: "gym_id,email" },
  );
  if (error) return fail(error);
  revalidatePath("/staff");
  return ok(null);
}

/** Отключение сотрудника без удаления истории */
export async function setStaffActive(id: string, active: boolean): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  if (id === ctx.staff.id) return { ok: false, error: { code: "INVALID_INPUT", message: "Нельзя отключить самого себя" } };
  const supabase = await createClient();
  const { error } = await supabase.from("staff").update({ active }).eq("id", id);
  if (error) return fail(error);
  revalidatePath("/staff");
  return ok(null);
}

export async function changeStaffRole(id: string, role: Role): Promise<ActionResult<null>> {
  const ctx = await requireStaff(["owner"]);
  if (id === ctx.staff.id) return { ok: false, error: { code: "INVALID_INPUT", message: "Нельзя изменить свою роль" } };
  const supabase = await createClient();
  const { error } = await supabase.from("staff").update({ role }).eq("id", id);
  if (error) return fail(error);
  revalidatePath("/staff");
  return ok(null);
}
