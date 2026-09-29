"use client";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { freezeMembership } from "@/app/actions/memberships";
import { addDays, date, daysBetween } from "@/lib/format";
import type { Membership } from "@/lib/types";
import { DatePicker } from "@/components/ui/date-picker";

/** FR-3.4 Заморозка в пределах лимита тарифа */
export function FreezeDialog({ membership, clientId, today, onClose }: { membership: Membership; clientId: string; today: string; onClose: () => void }) {
  const left = membership.freeze_days_max - membership.freeze_days_used;
  const [from, setFrom] = useState(today > membership.starts_on ? today : membership.starts_on);
  const [to, setTo] = useState(addDays(today > membership.starts_on ? today : membership.starts_on, Math.min(left, 7) - 1));
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const days = from && to ? daysBetween(from, to) + 1 : 0;

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Заморозка абонемента</DialogTitle>
          <DialogDescription>{membership.plan_name}: доступно {left} дн. из {membership.freeze_days_max}. Дата окончания сдвинется автоматически.</DialogDescription>
        </DialogHeader>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="С"><DatePicker value={from} min={today} max={membership.ends_on} onChange={setFrom} aria-label="С" /></Field>
          <Field label="По"><DatePicker value={to} min={from} onChange={setTo} aria-label="По" /></Field>
        </div>
        <Field label="Причина (необязательно)"><Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Отпуск, болезнь…" /></Field>
        {days > 0 ? (
          <p className="text-sm text-muted-foreground">
            {days} дн. · абонемент будет действовать до <b className="text-foreground">{date(addDays(membership.ends_on, days))}</b>
          </p>
        ) : null}
        {days > left ? <Alert variant="warning">Превышен лимит заморозки тарифа — доступно {left} дн.</Alert> : null}
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Отмена</Button>
          <Button disabled={pending || days <= 0 || days > left} onClick={() => start(async () => {
            const r = await freezeMembership({ membershipId: membership.id, clientId, from, to, reason });
            if (!r.ok) return setError(r.error.message);
            toast.success(`Абонемент заморожен на ${days} дн.`);
            onClose();
          })}>{pending ? "Сохраняем…" : "Заморозить"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
