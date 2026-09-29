import "server-only";
import { createClient } from "@/lib/supabase/server";
import { fail, ok, type ActionResult } from "@/lib/errors";

/** Вызов функции БД от имени сотрудника; ошибки → {code, message} */
export async function callRpc<T = unknown>(fn: string, args: Record<string, unknown> = {}): Promise<ActionResult<T>> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc(fn, args);
  if (error) return fail(error);
  return ok(data as T);
}

export function str(form: FormData, key: string): string {
  return String(form.get(key) ?? "").trim();
}

export function strOrNull(form: FormData, key: string): string | null {
  const v = str(form, key);
  return v === "" ? null : v;
}

export function intOrNull(form: FormData, key: string): number | null {
  const v = str(form, key);
  if (v === "") return null;
  const n = Number(v);
  return Number.isFinite(n) ? Math.trunc(n) : null;
}
