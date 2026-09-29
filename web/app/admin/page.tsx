import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { Logo } from "@/components/logo";
import { getUser, isPlatformAdmin } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { signOut } from "@/app/actions/auth";
import { AdminGyms, type AdminGym } from "./admin-gyms";

export const metadata: Metadata = { title: "Залы — команда core." };

/** 5.10 Управление залами (для команды core.): без доступа к персональным данным клиентов */
export default async function AdminPage() {
  if (!(await getUser())) redirect("/login");
  if (!(await isPlatformAdmin())) redirect("/");
  const supabase = await createClient();
  const { data } = await supabase.rpc("admin_list_gyms");
  return (
    <div className="min-h-dvh">
      <header className="glass glass-rim sticky top-3 z-30 mx-3 mt-3 flex h-14 items-center justify-between rounded-full px-6">
        <div className="flex items-center gap-3"><Logo className="h-5" /><span className="text-[15px] text-muted-foreground">команда</span></div>
        <form action={signOut}><button className="cursor-pointer text-[17px] text-tint-text active:opacity-60">Выйти</button></form>
      </header>
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <AdminGyms gyms={(data ?? []) as AdminGym[]} />
      </main>
    </div>
  );
}
