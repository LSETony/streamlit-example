import { NextResponse, type NextRequest } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";

// Возврат из письма: подтверждение email, восстановление пароля, приглашение сотрудника
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const next = url.searchParams.get("next") ?? "/";
  const safeNext = next.startsWith("/") ? next : "/";
  const supabase = await createClient();

  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type") as EmailOtpType | null;

  let error: unknown = null;
  if (code) {
    ({ error } = await supabase.auth.exchangeCodeForSession(code));
  } else if (tokenHash && type) {
    ({ error } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type }));
  } else {
    error = new Error("no code");
  }
  if (error) return NextResponse.redirect(new URL("/login?error=link", url.origin));
  const target = type === "invite" || type === "recovery" ? "/reset-password" : safeNext;
  return NextResponse.redirect(new URL(target, url.origin));
}
