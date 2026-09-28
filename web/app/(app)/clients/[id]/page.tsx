import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import type { Client, Membership, RiskRow } from "@/lib/types";
import { ClientCard } from "./client-card";

export const metadata: Metadata = { title: "Карточка клиента" };

export default async function ClientPage({ params, searchParams }: PageProps<"/clients/[id]">) {
  const ctx = await requireStaff();
  const { id } = await params;
  const sp = await searchParams;
  const supabase = await createClient();
  const { data: client } = await supabase.from("clients").select("*").eq("id", id).eq("gym_id", ctx.gym.id).is("deleted_at", null).maybeSingle();
  if (!client) notFound();

  const canMoney = ctx.staff.role !== "reception";
  const [memberships, freezes, visits, payments, bookings, risk] = await Promise.all([
    supabase.from("memberships").select("*").eq("client_id", id).order("starts_on", { ascending: false }),
    supabase.from("freezes").select("*, memberships!inner(client_id)").eq("memberships.client_id", id).order("from_date", { ascending: false }),
    supabase.from("visits").select("id, checked_in_at, checked_out_at, method").eq("client_id", id).order("checked_in_at", { ascending: false }).limit(100),
    canMoney
      ? supabase.from("payments").select("*").eq("client_id", id).order("created_at", { ascending: false })
      : Promise.resolve({ data: [] }),
    supabase.from("bookings").select("id, status, channel, created_at, schedule_items(id, title, starts_at, trainer_name, cancelled)").eq("client_id", id).order("created_at", { ascending: false }).limit(100),
    supabase.from("v_client_risk").select("*").eq("client_id", id).maybeSingle(),
  ]);

  return (
    <ClientCard
      client={client as Client}
      memberships={(memberships.data ?? []) as Membership[]}
      freezes={(freezes.data ?? []) as FreezeRow[]}
      visits={(visits.data ?? []) as VisitRow[]}
      payments={(payments.data ?? []) as PaymentRow[]}
      bookings={(bookings.data ?? []) as unknown as BookingRow[]}
      risk={(risk.data ?? null) as RiskRow | null}
      role={ctx.staff.role}
      gymId={ctx.gym.id}
      timezone={ctx.gym.timezone}
      today={ctx.today}
      readOnly={ctx.readOnly}
      openSell={sp.sell === "1"}
    />
  );
}

export interface FreezeRow { id: string; membership_id: string; from_date: string; to_date: string; days: number; reason: string | null }
export interface VisitRow { id: string; checked_in_at: string; checked_out_at: string | null; method: "qr" | "manual" }
export interface PaymentRow {
  id: string; amount: number; method: "cash" | "card" | "online"; status: "pending" | "succeeded" | "refunded" | "failed";
  refund_of_id: string | null; membership_id: string | null; paid_at: string | null; created_at: string; description: string | null; confirmation_url: string | null;
}
export interface BookingRow {
  id: string; status: "booked" | "cancelled" | "attended" | "no_show"; channel: "app" | "staff"; created_at: string;
  schedule_items: { id: string; title: string; starts_at: string; trainer_name: string | null; cancelled: boolean } | null;
}
