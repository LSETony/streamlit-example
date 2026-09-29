import { redirect } from "next/navigation";
import { getStaffContext, getUser, homeFor, isPlatformAdmin } from "@/lib/auth";

export default async function Home() {
  const user = await getUser();
  if (!user) redirect("/login");
  const ctx = await getStaffContext();
  if (ctx) redirect(homeFor(ctx.staff.role));
  if (await isPlatformAdmin()) redirect("/admin");
  redirect("/onboarding");
}
