"use client";
import { createBrowserClient } from "@supabase/ssr";
import { ANON_KEY, PUBLIC_URL, SESSION_COOKIE } from "./config";

// Клиент Supabase в браузере: быстрые операции ресепшена (скан QR) и Realtime
export function createClient() {
  return createBrowserClient(PUBLIC_URL, ANON_KEY, { cookieOptions: { name: SESSION_COOKIE } });
}
