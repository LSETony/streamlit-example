import { Badge } from "@/components/ui/badge";
import { dateShort } from "@/lib/format";
import type { MembershipState, MembershipStatus, PaymentStatus, RiskReason } from "@/lib/types";
import { RISK_LABEL } from "@/lib/types";

export function MembershipStateBadge({ state, endsOn }: { state: MembershipState; endsOn?: string | null }) {
  switch (state) {
    case "active":
      return <Badge variant="success">до {dateShort(endsOn)}</Badge>;
    case "frozen":
      return <Badge variant="info">Заморожен</Badge>;
    case "future":
      return <Badge variant="outline">Начнётся</Badge>;
    case "expired":
      return <Badge variant="danger">Закончился</Badge>;
    default:
      return <Badge variant="outline">Нет абонемента</Badge>;
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
  const s = STATUS[status];
  return <Badge variant={s.variant}>{s.label}</Badge>;
}

const PAY: Record<PaymentStatus, { label: string; variant: "success" | "warning" | "danger" | "outline" }> = {
  succeeded: { label: "Оплачено", variant: "success" },
  pending: { label: "Ожидает", variant: "warning" },
  refunded: { label: "Возвращено", variant: "outline" },
  failed: { label: "Не прошла", variant: "danger" },
};

export function PaymentStatusBadge({ status, isRefund }: { status: PaymentStatus; isRefund?: boolean }) {
  if (isRefund) {
    return status === "refunded" ? <Badge variant="danger">Возврат</Badge>
      : status === "pending" ? <Badge variant="warning">Возврат в процессе</Badge>
      : <Badge variant="outline">Возврат не прошёл</Badge>;
  }
  const s = PAY[status];
  return <Badge variant={s.variant}>{s.label}</Badge>;
}

const RISK_VARIANT: Record<RiskReason, "danger" | "warning" | "info" | "default"> = {
  not_renewed: "danger", expiring: "warning", gone: "info", declining: "default",
};

export function RiskBadge({ reason }: { reason: RiskReason }) {
  return <Badge variant={RISK_VARIANT[reason]}>{RISK_LABEL[reason]}</Badge>;
}
