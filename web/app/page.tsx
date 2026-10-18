import { redirect } from "next/navigation";
import { getStaffContext, getUser, homeFor, isPlatformAdmin } from "@/lib/auth";

export default async function Home() {
  const user = await getUser();
  if (!user) redirect("/login");
  // клиент зала вошёл по телефону — его место в приложении клиента, а не в кабинете
  if (!user.email && user.phone) redirect("/m");
  const ctx = await getStaffContext();
  if (ctx) redirect(homeFor(ctx.staff.role));
  if (await isPlatformAdmin()) redirect("/admin");
  redirect("/onboarding");
}
