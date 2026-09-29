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
      <header className="flex h-16 items-center justify-between bg-sidebar px-6 text-white">
        <div className="flex items-center gap-3"><Logo className="h-6" /><span className="text-sm text-sidebar-foreground">команда</span></div>
        <form action={signOut}><button className="cursor-pointer text-sm text-sidebar-foreground hover:text-white">Выйти</button></form>
      </header>
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
        <AdminGyms gyms={(data ?? []) as AdminGym[]} />
      </main>
    </div>
  );
}
