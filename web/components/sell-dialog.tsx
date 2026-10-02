"use client";
import { useEffect, useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Banknote, CreditCard, Link2, Copy } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createClient } from "@/lib/supabase/client";
import { sellMembership, createPaymentLink } from "@/app/actions/memberships";
import { addDays, date, money } from "@/lib/format";
import type { Plan } from "@/lib/types";
import { PLAN_KIND_LABEL } from "@/lib/types";
import { cn } from "@/lib/utils";
import { DatePicker } from "@/components/ui/date-picker";
import { useT } from "@/lib/i18n/client";

type Method = "cash" | "card" | "online";

/** FR-3.2 / FR-3.3 Продажа и продление абонемента: тариф, дата начала, способ оплаты */
export function SellDialog({ open, onOpenChange, gymId, client, today, renew, onDone }: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  gymId: string;
  client: { id: string; full_name: string };
  today: string;
  renew?: { id: string; ends_on: string; plan_id: string | null } | null;
  onDone?: () => void;
}) {
  // диалог монтируется заново при каждом открытии, поэтому начальное состояние берём из пропсов
  const t = useT();
  const [plans, setPlans] = useState<Plan[] | null>(null);
  const [planId, setPlanId] = useState<string>("");
  const [startsOn, setStartsOn] = useState(renew ? (renew.ends_on >= today ? addDays(renew.ends_on, 1) : today) : today);
  const [method, setMethod] = useState<Method>("card");
  const [error, setError] = useState<string | null>(null);
  const [link, setLink] = useState<string | null>(null);
  const [pending, start] = useTransition();

  useEffect(() => {
    if (!open) return;
    createClient().from("membership_plans").select("*").eq("gym_id", gymId).eq("active", true).order("price")
      .then(({ data }) => {
        const list = (data ?? []) as Plan[];
        setPlans(list);
        setPlanId((renew?.plan_id && list.some((p) => p.id === renew.plan_id)) ? renew.plan_id : list[0]?.id ?? "");
      });
  }, [open, gymId, renew, today]);

  const plan = plans?.find((p) => p.id === planId);
  const endsOn = plan ? addDays(startsOn, plan.duration_days - 1) : null;

  function submit() {
    if (!plan) return;
    setError(null);
    start(async () => {
      if (method === "online") {
        const res = await createPaymentLink({ clientId: client.id, planId: plan.id, startsOn, renewFrom: renew?.id });
        if (!res.ok) return setError(res.error.message);
        setLink(res.data.confirmation_url);
        return;
      }
      const res = await sellMembership({ clientId: client.id, planId: plan.id, method, startsOn: renew ? null : startsOn, renewFrom: renew?.id });
      if (!res.ok) return setError(res.error.message);
      toast.success(renew ? "Продлено: «{plan}» до {date}" : "Продано: «{plan}» до {date}", { plan: plan.name, date: date(res.data.membership.ends_on) });
      onOpenChange(false);
      onDone?.();
    });
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{renew ? "Продление абонемента" : "Продажа абонемента"}</DialogTitle>
          <DialogDescription>{client.full_name}</DialogDescription>
        </DialogHeader>

        {link !== null ? (
          <div className="grid gap-3">
            <Alert variant="success">Ссылка на оплату создана. Абонемент активируется автоматически после оплаты.</Alert>
            {link ? (
              <div className="flex gap-2">
                <Input readOnly value={link} onFocus={(e) => e.currentTarget.select()} />
                <Button variant="outline" size="icon" onClick={() => { navigator.clipboard.writeText(link); toast.success("Ссылка скопирована"); }} aria-label="Скопировать">
                  <Copy />
                </Button>
              </div>
            ) : null}
            <DialogFooter><Button onClick={() => { onOpenChange(false); onDone?.(); }}>Готово</Button></DialogFooter>
          </div>
        ) : plans === null ? (
          <p className="text-sm text-muted-foreground">{t("Загружаем тарифы…")}</p>
        ) : plans.length === 0 ? (
          <Alert variant="warning">В зале нет активных тарифов. Владелец может создать их в разделе «Тарифы».</Alert>
        ) : (
          <div className="grid gap-4">
            <div className="grid gap-2" role="radiogroup" aria-label={t("Тариф")}>
              {plans.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  role="radio"
                  aria-checked={p.id === planId}
                  onClick={() => setPlanId(p.id)}
                  className={cn(
                    "flex cursor-pointer items-center justify-between rounded-xl border px-4 py-3 text-left transition-colors",
                    p.id === planId ? "border-foreground bg-muted/60" : "border-border hover:bg-muted/40",
                  )}
                >
                  <span>
                    <span className="block font-medium">{p.name}</span>
                    <span className="text-xs text-muted-foreground">
                      {t(PLAN_KIND_LABEL[p.kind])} · {p.duration_days} {t.n(p.duration_days, "день|дня|дней")}
                      {p.visits_limit ? ` · ${p.visits_limit} ${t.n(p.visits_limit, "визит|визита|визитов")}` : ""}
                    </span>
                  </span>
                  <span className="font-semibold tabular">{money(p.price)}</span>
                </button>
              ))}
            </div>

            {!renew ? (
              <Field label="Дата начала" hint={endsOn ? t("Действует до {date}", { date: date(endsOn) }) : undefined}>
                <DatePicker value={startsOn} min={addDays(today, -30)} onChange={setStartsOn} aria-label="Начало" />
              </Field>
            ) : (
              <p className="text-sm text-muted-foreground">
                {endsOn ? t("Новый абонемент начнётся {start} и будет действовать до {end}.", { start: date(startsOn), end: date(endsOn) }) : t("Новый абонемент начнётся {start}.", { start: date(startsOn) })}
              </p>
            )}

            <div className="grid gap-1.5">
              <span className="text-sm font-medium">{t("Оплата")}</span>
              <div className="grid grid-cols-3 gap-2">
                {([
                  ["card", "Карта", CreditCard],
                  ["cash", "Наличные", Banknote],
                  ["online", "Ссылка", Link2],
                ] as const).map(([m, label, Icon]) => (
                  <button
                    key={m}
                    type="button"
                    onClick={() => setMethod(m)}
                    className={cn(
                      "flex cursor-pointer flex-col items-center gap-1 rounded-xl border px-2 py-3 text-sm transition-colors",
                      method === m ? "border-foreground bg-muted/60 font-medium" : "border-border text-muted-foreground hover:bg-muted/40",
                    )}
                    aria-pressed={method === m}
                  >
                    <Icon className="size-5" />
                    {t(label)}
                  </button>
                ))}
              </div>
              {method === "online" ? (
                <p className="text-xs text-muted-foreground">{t("Клиент оплатит картой или через СБП по ссылке ЮKassa, чек придёт автоматически.")}</p>
              ) : null}
            </div>

            {error ? <Alert variant="danger">{error}</Alert> : null}
            <DialogFooter>
              <Button variant="outline" onClick={() => onOpenChange(false)}>Отмена</Button>
              <Button onClick={submit} disabled={pending || !plan}>
                {pending ? "Оформляем…" : method === "online" ? "Создать ссылку" : t("Принять {sum}", { sum: plan ? money(plan.price) : "" })}
              </Button>
            </DialogFooter>
          </div>
        )}
      </DialogContent>
    </Dialog>
  );
}
