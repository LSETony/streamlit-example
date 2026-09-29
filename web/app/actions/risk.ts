"use server";
import { revalidatePath } from "next/cache";
import { callRpc } from "@/lib/actions";
import type { ActionResult } from "@/lib/errors";
import { requireStaff } from "@/lib/auth";

/** FR-8.2 Отметить «связались» (и отправить push, если канал push) */
export async function markContacted(input: {
  clientId: string; reason: string; channel: "call" | "telegram" | "whatsapp" | "push" | "other"; note?: string; pushText?: string;
}): Promise<ActionResult<string>> {
  await requireStaff();
  const res = await callRpc<string>("mark_contacted", {
    p_client: input.clientId, p_reason: input.reason, p_channel: input.channel, p_note: input.note || null, p_push_text: input.pushText || null,
  });
  if (res.ok) revalidatePath("/risk");
  return res;
}
