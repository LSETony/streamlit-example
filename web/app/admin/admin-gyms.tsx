"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { TIMEZONES } from "@/components/gym-settings-forms";
import { adminCreateGym, adminUpdateGym } from "@/app/actions/admin";
import { date } from "@/lib/format";

export interface AdminGym {
  id: string; name: string; address: string | null; core_plan: "start" | "business" | "network"; trial_until: string; paid_until: string | null;
  features: Record<string, boolean>; read_only: boolean; clients_count: number; visits_week: number; owner_email: string | null; created_at: string;
}

const PLAN = { start: "Старт", business: "Бизнес", network: "Сеть" } as const;
const FEATURES: [string, string][] = [
  ["dashboard", "Дашборд"], ["risk", "В зоне риска"], ["schedule", "Расписание и бронь"], ["online_payments", "Онлайн-оплата"],
  ["import", "Импорт"], ["export", "Экспорт"], ["notifications", "Уведомления"], ["audit", "Журнал действий"],
];

export function AdminGyms({ gyms }: { gyms: AdminGym[] }) {
  const router = useRouter();
  const [edit, setEdit] = useState<AdminGym | null>(null);
  const [create, setCreate] = useState(false);
  return (
    <>
      <div className="mb-6 flex items-end justify-between">
        <div>
          <h1 className="text-[34px] font-bold leading-[41px] tracking-[-0.02em]">Залы</h1>
          <p className="text-sm text-muted-foreground">{gyms.length} · персональные данные клиентов недоступны без запроса поддержки</p>
        </div>
        <Button onClick={() => setCreate(true)}><Plus /> Новый зал</Button>
      </div>
      <Card>
        <Table>
          <THead><TR><TH>Зал</TH><TH>Тариф</TH><TH>Подписка</TH><TH>Клиентов</TH><TH>Визитов за неделю</TH><TH /></TR></THead>
          <TBody>
            {gyms.map((g) => (
              <TR key={g.id}>
                <TD><p className="font-medium">{g.name}</p><p className="text-xs text-muted-foreground">{g.owner_email ?? "—"}{g.address ? ` · ${g.address}` : ""}</p></TD>
                <TD>{PLAN[g.core_plan]}</TD>
                <TD>
                  {g.read_only ? <Badge variant="danger">Только чтение</Badge>
                    : g.paid_until ? <Badge variant="success">Оплачено до {date(g.paid_until)}</Badge>
                    : <Badge variant="warning">Пробный до {date(g.trial_until)}</Badge>}
                </TD>
                <TD className="tabular">{g.clients_count}</TD>
                <TD className="tabular">{g.visits_week}</TD>
                <TD className="text-right"><Button size="sm" variant="outline" onClick={() => setEdit(g)}>Управлять</Button></TD>
              </TR>
            ))}
          </TBody>
        </Table>
      </Card>
      {edit ? <EditGym gym={edit} onClose={() => { setEdit(null); router.refresh(); }} /> : null}
      {create ? <CreateGym onClose={() => { setCreate(false); router.refresh(); }} /> : null}
    </>
  );
}

function EditGym({ gym, onClose }: { gym: AdminGym; onClose: () => void }) {
  const [plan, setPlan] = useState(gym.core_plan);
  const [trial, setTrial] = useState(gym.trial_until);
  const [paid, setPaid] = useState(gym.paid_until ?? "");
  const [features, setFeatures] = useState<Record<string, boolean>>(gym.features);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent wide>
        <DialogHeader><DialogTitle>{gym.name}</DialogTitle><DialogDescription>Тариф core., пробный период, оплата и флаги функций</DialogDescription></DialogHeader>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Тариф"><NativeSelect value={plan} onChange={(e) => setPlan(e.target.value as AdminGym["core_plan"])}>
            {Object.entries(PLAN).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</NativeSelect></Field>
          <Field label="Пробный период до"><Input type="date" value={trial} onChange={(e) => setTrial(e.target.value)} /></Field>
          <Field label="Оплачено до" hint="Пусто — не оплачено"><Input type="date" value={paid} onChange={(e) => setPaid(e.target.value)} /></Field>
        </div>
        <div className="grid gap-2 sm:grid-cols-2">
          {FEATURES.map(([k, l]) => (
            <Checkbox key={k} checked={features[k] !== false} onChange={(e) => setFeatures((f) => ({ ...f, [k]: e.target.checked }))} label={l} />
          ))}
        </div>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Отмена</Button>
          <Button disabled={pending} onClick={() => start(async () => {
            const r = await adminUpdateGym({ gymId: gym.id, corePlan: plan, trialUntil: trial, paidUntil: paid || null, features });
            if (!r.ok) return setError(r.error.message);
            toast.success("Сохранено");
            onClose();
          })}>Сохранить</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function CreateGym({ onClose }: { onClose: () => void }) {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent>
        <DialogHeader><DialogTitle>Новый зал</DialogTitle><DialogDescription>Владелец получит приглашение на email</DialogDescription></DialogHeader>
        <form className="grid gap-4" action={(f) => start(async () => {
          const r = await adminCreateGym(f);
          if (!r.ok) return setError(r.error.message);
          toast.success("Зал создан, приглашение отправлено");
          onClose();
        })}>
          <Field label="Название"><Input name="name" required /></Field>
          <Field label="Адрес"><Input name="address" /></Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Имя владельца"><Input name="owner_name" required /></Field>
            <Field label="Email владельца"><Input name="owner_email" type="email" required /></Field>
            <Field label="Часовой пояс"><NativeSelect name="timezone" defaultValue="Europe/Moscow">{TIMEZONES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</NativeSelect></Field>
            <Field label="Тариф"><NativeSelect name="core_plan" defaultValue="start">{Object.entries(PLAN).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</NativeSelect></Field>
            <Field label="Пробный период, дней"><Input name="trial_days" type="number" defaultValue={14} min={0} /></Field>
          </div>
          {error ? <Alert variant="danger">{error}</Alert> : null}
          <DialogFooter><Button type="button" variant="outline" onClick={onClose}>Отмена</Button><Button type="submit" disabled={pending}>Создать</Button></DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
