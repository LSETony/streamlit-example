"use client";
import { Badge } from "@/components/ui/badge";
import { dateShort } from "@/lib/format";
import type { MembershipState, MembershipStatus, PaymentStatus, RiskReason } from "@/lib/types";
import { RISK_LABEL } from "@/lib/types";
import { useT } from "@/lib/i18n/client";

export function MembershipStateBadge({ state, endsOn }: { state: MembershipState; endsOn?: string | null }) {
  const t = useT();
  switch (state) {
    case "active":
      return <Badge variant="success">{t("до {date}", { date: dateShort(endsOn, t.intl) })}</Badge>;
    case "frozen":
      return <Badge variant="info">{t("Заморожен")}</Badge>;
    case "future":
      return <Badge variant="outline">{t("Начнётся")}</Badge>;
    case "expired":
      return <Badge variant="danger">{t("Закончился")}</Badge>;
    default:
      return <Badge variant="outline">{t("Нет абонемента")}</Badge>;
  }
}

const STATUS: Record<MembershipStatus, { label: string; variant: "success" | "info" | "danger" | "outline" | "warning" }> = {
  active: { label: "Действует", variant: "success" },
  frozen: { label: "Заморожен", variant: "info" },
  pending: { label: "Ждёт оплаты", variant: "warning" },
  expired: { label: "Закончился", variant: "outline" },
  cancelled: { label: "Отменён", variant: "danger" },
};

export function MembershipStatusBadge({ status }: { status: MembershipStatus }) {
  const t = useT();
  const s = STATUS[status];
  return <Badge variant={s.variant}>{t(s.label)}</Badge>;
}

const PAY: Record<PaymentStatus, { label: string; variant: "success" | "warning" | "danger" | "outline" }> = {
  succeeded: { label: "Оплачено", variant: "success" },
  pending: { label: "Ожидает", variant: "warning" },
  refunded: { label: "Возвращено", variant: "outline" },
  failed: { label: "Не прошла", variant: "danger" },
};

export function PaymentStatusBadge({ status, isRefund }: { status: PaymentStatus; isRefund?: boolean }) {
  const t = useT();
  if (isRefund) {
    return status === "refunded" ? <Badge variant="danger">{t("Возврат")}</Badge>
      : status === "pending" ? <Badge variant="warning">{t("Возврат в процессе")}</Badge>
      : <Badge variant="outline">{t("Возврат не прошёл")}</Badge>;
  }
  const s = PAY[status];
  return <Badge variant={s.variant}>{t(s.label)}</Badge>;
}

const RISK_VARIANT: Record<RiskReason, "danger" | "warning" | "info" | "default"> = {
  not_renewed: "danger", expiring: "warning", gone: "info", declining: "default",
};

export function RiskBadge({ reason }: { reason: RiskReason }) {
  const t = useT();
  return <Badge variant={RISK_VARIANT[reason]}>{t(RISK_LABEL[reason])}</Badge>;
}
