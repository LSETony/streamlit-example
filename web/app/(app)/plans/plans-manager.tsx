"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus, Smartphone, Tags } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input, NativeSelect, Textarea } from "@/components/ui/input";
import { Alert, EmptyState } from "@/components/ui/misc";
import { savePlan, setPlanActive } from "@/app/actions/plans";
import { money, plural } from "@/lib/format";
import type { Plan, PlanKind } from "@/lib/types";
import { PLAN_KIND_LABEL } from "@/lib/types";

export function PlansManager({ plans, readOnly }: { plans: Plan[]; readOnly: boolean }) {
  const router = useRouter();
  const [edit, setEdit] = useState<Plan | "new" | null>(null);
  const [, start] = useTransition();
  return (
    <>
      <div className="mb-4 flex justify-end">
        <Button onClick={() => setEdit("new")} disabled={readOnly}><Plus /> Новый тариф</Button>
      </div>
      {plans.length === 0 ? (
        <EmptyState icon={<Tags />} title="Тарифов пока нет" action={<Button onClick={() => setEdit("new")}><Plus /> Создать тариф</Button>}>
          Тарифы трёх типов: на срок, на число визитов и безлимит.
        </EmptyState>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {plans.map((p) => (
            <Card key={p.id} className={p.active ? "grid gap-4 p-5" : "grid gap-4 p-5 opacity-60"}>
              <div className="flex items-start justify-between gap-2">
                <div>
                  <p className="text-lg font-semibold">{p.name}</p>
                  <p className="text-sm text-muted-foreground">{PLAN_KIND_LABEL[p.kind]}</p>
                </div>
                <p className="text-xl font-semibold tabular">{money(p.price)}</p>
              </div>
              <ul className="grid gap-1 text-sm">
                <li>Срок: {p.duration_days} {plural(p.duration_days, "день", "дня", "дней")}</li>
                {p.visits_limit ? <li>Визитов: {p.visits_limit}</li> : null}
                <li>Заморозка: {p.freeze_days_max ? `до ${p.freeze_days_max} дн.` : "нет"}</li>
              </ul>
              <div className="flex flex-wrap items-center gap-2">
                {p.sold_online ? <Badge variant="brand"><Smartphone className="size-3" /> продаётся в приложении</Badge> : null}
                {!p.active ? <Badge variant="outline">в архиве</Badge> : null}
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm" onClick={() => setEdit(p)} disabled={readOnly}>Изменить</Button>
                <Button variant="ghost" size="sm" disabled={readOnly} onClick={() => start(async () => {
                  const r = await setPlanActive(p.id, !p.active);
                  if (!r.ok) toast.error(r.error.message); else router.refresh();
                })}>{p.active ? "В архив" : "Вернуть в продажу"}</Button>
              </div>
            </Card>
          ))}
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
          <Checkbox name="sold_online" defaultChecked={plan?.sold_online ?? true} label="Продаётся в приложении (онлайн-оплата)" />
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
