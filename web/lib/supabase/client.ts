"use client";
import { createBrowserClient } from "@supabase/ssr";

// Клиент Supabase в браузере: быстрые операции ресепшена (скан QR) и Realtime
export function createClient() {
  return createBrowserClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
}
