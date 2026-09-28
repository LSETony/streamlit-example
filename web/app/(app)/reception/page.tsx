import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { ReceptionScreen } from "./reception-screen";

export const metadata: Metadata = { title: "Ресепшен" };

export default async function ReceptionPage() {
  const ctx = await requireStaff();
  const capacity = ctx.gym.settings?.capacity ?? 0;
  return (
    <ReceptionScreen
      gymId={ctx.gym.id}
      timezone={ctx.gym.timezone}
      today={ctx.today}
      capacity={capacity}
      readOnly={ctx.readOnly}
    />
  );
}
