"use server";
import { revalidatePath } from "next/cache";
import { callRpc } from "@/lib/actions";
import type { ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";
import type { CheckinResult } from "@/lib/types";

export async function checkinManual(clientId: string): Promise<ActionResult<CheckinResult>> {
  await requireStaff();
  const res = await callRpc<CheckinResult>("checkin_manual", { p_client: clientId });
  revalidatePath(`/clients/${clientId}`);
  return res;
}

export async function checkoutVisit(visitId: string): Promise<ActionResult<null>> {
  await requireStaff();
  return callRpc<null>("checkout_visit", { p_visit: visitId });
}
