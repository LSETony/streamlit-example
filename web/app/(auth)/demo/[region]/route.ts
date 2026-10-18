import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { LOCALE_COOKIE } from "@/lib/i18n/core";

// Демо-залы из supabase/demo.sql: только чтение, вход одноразовой ссылкой — пароль нигде не хранится
const DEMO: Record<string, { email: string; locale: "ru" | "en" }> = {
  ae: { email: "demo-ae@demo.core", locale: "en" },
  ru: { email: "demo-ru@demo.core", locale: "ru" },
};

export async function GET(request: NextRequest, { params }: { params: Promise<{ region: string }> }) {
  const demo = DEMO[(await params).region];
  const fail = NextResponse.redirect(new URL("/demo?error=1", request.url));
  if (!demo) return NextResponse.redirect(new URL("/demo", request.url));
  let admin;
  try { admin = createAdminClient(); } catch { return fail; }
  const { data, error } = await admin.auth.admin.generateLink({ type: "magiclink", email: demo.email });
  const tokenHash = data?.properties?.hashed_token;
  if (error || !tokenHash) return fail;
  const supabase = await createClient();
  const { error: verifyError } = await supabase.auth.verifyOtp({ token_hash: tokenHash, type: "magiclink" });
  if (verifyError) return fail;
  const response = NextResponse.redirect(new URL("/dashboard", request.url));
  response.cookies.set(LOCALE_COOKIE, demo.locale, { path: "/", maxAge: 60 * 60 * 24 * 365, sameSite: "lax" });
  return response;
}
