// Типы строк базы, которые использует кабинет (упрощённо; источник правды — миграции supabase/)
export type Role = "owner" | "admin" | "reception";
export type PlanKind = "period" | "visits" | "unlimited";
export type MembershipStatus = "pending" | "active" | "frozen" | "expired" | "cancelled";
export type PaymentMethod = "cash" | "card" | "online";
export type PaymentStatus = "pending" | "succeeded" | "refunded" | "failed";
export type MembershipState = "active" | "frozen" | "future" | "expired" | "none";
export type RiskReason = "gone" | "expiring" | "declining" | "not_renewed";

export interface GymSettings {
  risk: { gone_days: number; expiring_days: number; declining_ratio: number; not_renewed_days: number };
  hours: Record<string, [string, string] | null>;
  auto_checkout_hours: number;
  booking_cancel_hours: number;
  allow_app_freeze: boolean;
  capacity: number;
  notify_fallback: "sms" | "email" | "none";
  message_templates: Record<RiskReason, string>;
}

export interface Gym {
  id: string;
  name: string;
  address: string | null;
  timezone: string;
  phone: string | null;
  logo_url: string | null;
  core_plan: "start" | "business" | "network";
  trial_until: string;
  paid_until: string | null;
  settings: GymSettings;
  onboarded_at: string | null;
  region: "RU" | "AE";
  currency: "RUB" | "AED";
}

export interface Plan {
  id: string;
  gym_id: string;
  name: string;
  description: string | null;
  kind: PlanKind;
  price: number;
  duration_days: number;
  visits_limit: number | null;
  freeze_days_max: number;
  sold_online: boolean;
  active: boolean;
}

export interface Membership {
  id: string;
  client_id: string;
  plan_id: string | null;
  plan_name: string;
  kind: PlanKind;
  starts_on: string;
  ends_on: string;
  visits_left: number | null;
  freeze_days_max: number;
  freeze_days_used: number;
  status: MembershipStatus;
  price_paid: number;
  renewed_from_id: string | null;
  imported: boolean;
  created_at: string;
}

export interface Client {
  id: string;
  gym_id: string;
  user_id: string | null;
  full_name: string;
  phone: string | null;
  email: string | null;
  birth_date: string | null;
  gender: "male" | "female" | null;
  source: string | null;
  tags: string[];
  note: string | null;
  photo_url: string | null;
  consent_pd_at: string | null;
  consent_marketing_at: string | null;
  last_visit_at: string | null;
  created_at: string;
}

export interface ClientRow {
  id: string;
  full_name: string;
  phone: string | null;
  email: string | null;
  source: string | null;
  tags: string[];
  in_app: boolean;
  last_visit_at: string | null;
  created_at: string;
  membership_id: string | null;
  plan_name: string | null;
  membership_ends_on: string | null;
  visits_left: number | null;
  membership_state: MembershipState;
}

export interface RiskRow {
  client_id: string;
  full_name: string;
  phone: string | null;
  in_app: boolean;
  marketing_ok: boolean;
  last_visit_at: string | null;
  membership_ends_on: string | null;
  days_absent: number | null;
  days_left: number | null;
  days_since_end: number | null;
  reason: RiskReason;
  reasons: RiskReason[];
  reason_text: string;
  urgency: number;
  contacted_at: string | null;
  contact_channel: string | null;
}

export interface CheckinResult {
  ok: boolean;
  code: string;
  message: string;
  repeat?: boolean;
  visit_id?: string;
  client: { id: string; full_name: string; photo_url: string | null; phone: string | null } | null;
  membership: {
    id: string; plan_name: string; kind: PlanKind; status: MembershipStatus;
    starts_on: string; ends_on: string; visits_left: number | null; freeze_days_left: number;
  } | null;
}

export interface KpiPeriod {
  revenue: number;
  active_clients: number;
  renewal_rate: number | null;
  renewal_ended: number;
  renewal_renewed: number;
  churn: number;
  new_clients: number;
  new_by_source: { source: string; count: number }[];
}

export interface Occupancy {
  now: number;
  capacity: number;
  load_pct: number | null;
  heatmap: { dow: number; hour: number; avg: number }[];
  today_forecast: { hour: number; avg: number }[];
  timezone: string;
}

export interface Dashboard {
  period: { from: string; to: string };
  previous_period: { from: string; to: string };
  current: KpiPeriod;
  previous: KpiPeriod;
  occupancy: Occupancy;
}

export const ROLE_LABEL: Record<Role, string> = { owner: "Владелец", admin: "Администратор", reception: "Ресепшен" };
export const PLAN_KIND_LABEL: Record<PlanKind, string> = { period: "На срок", visits: "На визиты", unlimited: "Безлимит" };
export const METHOD_LABEL: Record<PaymentMethod, string> = { cash: "Наличные", card: "Карта", online: "Онлайн" };
export const RISK_LABEL: Record<RiskReason, string> = {
  gone: "Пропал", expiring: "Заканчивается", declining: "Стал ходить реже", not_renewed: "Не продлил",
};
