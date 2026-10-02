"use client";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { refundPayment } from "@/app/actions/memberships";
import { money, parseRub } from "@/lib/format";
import { METHOD_LABEL } from "@/lib/types";
import { useT } from "@/lib/i18n/client";

/** FR-6.3 / FR-3.6 Возврат полной или частичной суммы */
export function RefundDialog({ payment, clientId, onClose }: {
  payment: { id: string; amount: number; method: "cash" | "card" | "online"; membership_id: string | null };
  clientId?: string; onClose: () => void;
}) {
  const t = useT();
  const [amount, setAmount] = useState(String(payment.amount / 100));
  const [cancel, setCancel] = useState(true);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const kopecks = parseRub(amount);

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Возврат</DialogTitle>
          <DialogDescription>
            {t("Оплата")} {money(payment.amount)} · {t(METHOD_LABEL[payment.method])}.{" "}
            {payment.method === "online" ? t("Деньги вернутся на карту клиента через ЮKassa.") : t("Выдайте деньги клиенту на кассе.")}
          </DialogDescription>
        </DialogHeader>
        <Field label="Сумма возврата, ₽"><Input inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} /></Field>
        <Field label="Причина"><Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Переезд, по состоянию здоровья…" /></Field>
        {payment.membership_id ? <Checkbox checked={cancel} onChange={(e) => setCancel(e.target.checked)} label="Отменить абонемент" /> : null}
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Отмена</Button>
          <Button variant="destructive" disabled={pending || !kopecks || kopecks > payment.amount} onClick={() => start(async () => {
            const r = await refundPayment({ paymentId: payment.id, amount: kopecks, cancelMembership: cancel, reason, online: payment.method === "online", clientId });
            if (!r.ok) return setError(r.error.message);
            toast.success(r.data.status === "pending" ? "Возврат отправлен в ЮKassa" : "Возвращено {sum}", { sum: money(kopecks) });
            onClose();
          })}>{pending ? "Проводим…" : t("Вернуть {sum}", { sum: kopecks ? money(kopecks) : "" })}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
