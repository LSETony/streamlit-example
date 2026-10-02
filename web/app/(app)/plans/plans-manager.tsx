"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Archive, ArchiveRestore, Pencil, Plus, Smartphone, Tags } from "lucide-react";
import { PageHeader } from "@/components/app-shell";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, Input, NativeSelect, Textarea } from "@/components/ui/input";
import { SwitchRow } from "@/components/ui/switch";
import { Alert, EmptyState } from "@/components/ui/misc";
import { savePlan, setPlanActive } from "@/app/actions/plans";
import { money } from "@/lib/format";
import type { Plan, PlanKind } from "@/lib/types";
import { PLAN_KIND_LABEL } from "@/lib/types";
import { useT } from "@/lib/i18n/client";

export function PlansManager({ plans, readOnly }: { plans: Plan[]; readOnly: boolean }) {
  const t = useT();
  const router = useRouter();
  const [edit, setEdit] = useState<Plan | "new" | null>(null);
  const [, start] = useTransition();
  const active = plans.filter((p) => p.active);
  const archived = plans.filter((p) => !p.active);
  const card = (p: Plan) => (
    <Card key={p.id} className={cn("group flex flex-col overflow-hidden", !p.active && "opacity-60")}>
      <div className="flex flex-1 flex-col gap-5 p-5">
        <div className="flex items-start justify-between gap-3">
          <div className="grid gap-1">
            <span className="text-xs font-medium uppercase tracking-[0.06em] text-muted-foreground">{t(PLAN_KIND_LABEL[p.kind])}</span>
            <p className="text-lg font-semibold leading-tight">{p.name}</p>
          </div>
          {p.sold_online ? (
            <span title={t("Продаётся в приложении")} className="grid size-8 place-items-center rounded-full bg-brand-soft text-brand-ink"><Smartphone className="size-4" /></span>
          ) : null}
        </div>
        <p className="text-[28px] font-semibold leading-none tracking-tight tabular">{money(p.price)}</p>
        <dl className="grid grid-cols-3 gap-2 text-sm">
          <Meta label={t("Срок")} value={`${p.duration_days} ${t.n(p.duration_days, "день|дня|дней")}`} />
          <Meta label={t("Визиты")} value={p.visits_limit ? String(p.visits_limit) : "∞"} />
          <Meta label={t("Заморозка")} value={p.freeze_days_max ? `${p.freeze_days_max} ${t("дн.")}` : "—"} />
        </dl>
      </div>
      <div className="flex items-center justify-between border-t border-border bg-surface-2 px-3 py-2">
        <Button variant="ghost" size="sm" onClick={() => setEdit(p)} disabled={readOnly}><Pencil /> Изменить</Button>
        <Button variant="ghost" size="sm" disabled={readOnly} className="text-muted-foreground" onClick={() => start(async () => {
          const r = await setPlanActive(p.id, !p.active);
          if (!r.ok) toast.error(r.error.message); else router.refresh();
        })}>{p.active ? <><Archive /> В архив</> : <><ArchiveRestore /> Вернуть</>}</Button>
      </div>
    </Card>
  );
  return (
    <>
      <PageHeader
        title="Тарифы"
        description="Цена фиксируется в момент продажи — изменение тарифа не меняет уже проданные абонементы"
        actions={<Button onClick={() => setEdit("new")} disabled={readOnly}><Plus /> Новый тариф</Button>}
      />
      {plans.length === 0 ? (
        <EmptyState icon={<Tags />} title="Тарифов пока нет" action={<Button onClick={() => setEdit("new")}><Plus /> Создать тариф</Button>}>
          {t("Тарифы трёх типов: на срок, на число визитов и безлимит.")}
        </EmptyState>
      ) : (
        <div className="grid gap-8">
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">{active.map(card)}</div>
          {archived.length ? (
            <div className="grid gap-3">
              <h2 className="text-sm font-medium text-muted-foreground">{t("Архив · не продаются")}</h2>
              <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">{archived.map(card)}</div>
            </div>
          ) : null}
        </div>
      )}
      {edit ? <PlanDialog plan={edit === "new" ? null : edit} onClose={() => { setEdit(null); router.refresh(); }} /> : null}
    </>
  );
}

/** FR-3.1 Тарифы трёх типов: цена, срок, лимит заморозки, «продаётся в приложении» */
export function PlanDialog({ plan, onClose }: { plan: Plan | null; onClose: () => void }) {
  const [kind, setKind] = useState<PlanKind>(plan?.kind ?? "period");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent>
        <DialogHeader><DialogTitle>{plan ? "Тариф" : "Новый тариф"}</DialogTitle></DialogHeader>
        <form className="grid gap-4" action={(f) => start(async () => {
          const r = await savePlan(f);
          if (!r.ok) return setError(r.error.message);
          toast.success("Тариф сохранён");
          onClose();
        })}>
          {plan ? <input type="hidden" name="id" value={plan.id} /> : null}
          <Field label="Название"><Input name="name" defaultValue={plan?.name} required placeholder="Месяц безлимит" /></Field>
          <Field label="Тип">
            <NativeSelect name="kind" value={kind} onChange={(e) => setKind(e.target.value as PlanKind)}>
              <option value="period">На срок</option>
              <option value="visits">На число визитов</option>
              <option value="unlimited">Безлимит на срок</option>
            </NativeSelect>
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Цена, ₽"><Input name="price" inputMode="decimal" defaultValue={plan ? String(plan.price / 100) : ""} required placeholder="3000" /></Field>
            <Field label="Срок действия, дней"><Input name="duration_days" type="number" min={1} defaultValue={plan?.duration_days ?? 30} required /></Field>
            {kind === "visits" ? <Field label="Число визитов"><Input name="visits_limit" type="number" min={1} defaultValue={plan?.visits_limit ?? 10} required /></Field> : null}
            <Field label="Заморозка, дней максимум"><Input name="freeze_days_max" type="number" min={0} defaultValue={plan?.freeze_days_max ?? 0} /></Field>
          </div>
          <Field label="Описание для приложения"><Textarea name="description" rows={2} defaultValue={plan?.description ?? ""} /></Field>
          <SwitchRow name="sold_online" defaultChecked={plan?.sold_online ?? true} title="Продаётся в приложении" description="Клиенты смогут купить и продлить тариф онлайн" />
          {error ? <Alert variant="danger">{error}</Alert> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>Отмена</Button>
            <Button type="submit" disabled={pending}>{pending ? "Сохраняем…" : "Сохранить"}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

function Meta({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid gap-0.5 rounded-xl bg-field px-2.5 py-2">
      <dt className="text-[11px] text-muted-foreground">{label}</dt>
      <dd className="font-medium tabular">{value}</dd>
    </div>
  );
}
