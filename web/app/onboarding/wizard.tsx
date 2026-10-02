"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Check, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { HoursForm, TIMEZONES, ZonesEditor } from "@/components/gym-settings-forms";
import { createGym, finishOnboarding } from "@/app/actions/gym";
import { createTemplatePlans } from "@/app/actions/plans";
import { PlanDialog } from "@/app/(app)/plans/plans-manager";
import { InviteForm } from "@/app/(app)/staff/staff-manager";
import { money } from "@/lib/format";
import type { Gym, Plan } from "@/lib/types";
import { PLAN_KIND_LABEL, ROLE_LABEL, type Role } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useT } from "@/lib/i18n/client";

const STEPS = ["Зал", "Часы работы", "Зоны", "Тарифы", "Сотрудники", "Готово"];

const TEMPLATES = [
  { name: "Разовое посещение", kind: "visits" as const, price: 60000, duration_days: 1, visits_limit: 1, freeze_days_max: 0, sold_online: true },
  { name: "Месяц", kind: "unlimited" as const, price: 350000, duration_days: 30, visits_limit: null, freeze_days_max: 7, sold_online: true },
  { name: "8 занятий", kind: "visits" as const, price: 280000, duration_days: 45, visits_limit: 8, freeze_days_max: 7, sold_online: true },
  { name: "3 месяца", kind: "unlimited" as const, price: 900000, duration_days: 90, visits_limit: null, freeze_days_max: 14, sold_online: true },
  { name: "Год", kind: "unlimited" as const, price: 2900000, duration_days: 365, visits_limit: null, freeze_days_max: 30, sold_online: false },
];

export function Wizard({ step, gym, zones, plans, staff, email }: {
  step: number; gym: Gym | null; zones: { id: string; name: string; capacity: number }[]; plans: Plan[];
  staff: { id: string; full_name: string; email: string; role: string }[]; email: string;
}) {
  const t = useT();
  const router = useRouter();
  const go = (s: number) => router.push(`/onboarding?step=${s}`);
  return (
    <div className="grid gap-8">
      <ol className="flex flex-wrap gap-x-5 gap-y-2 text-sm">
        {STEPS.map((s, i) => (
          <li key={s} className={cn("flex items-center gap-2", i === step ? "font-semibold" : "text-muted-foreground")}>
            <span className={cn("grid size-6 place-items-center rounded-full text-xs", i < step ? "bg-tint-soft text-tint-text" : i === step ? "bg-tint text-white" : "bg-field")}>
              {i < step ? <Check className="size-3.5" /> : i + 1}
            </span>
            {t(s)}
          </li>
        ))}
      </ol>

      {step === 0 ? <CreateGymStep email={email} /> : null}

      {step === 1 && gym ? (
        <StepCard title="Часы работы" description="Нужны для расписания, тепловой карты загруженности и тихих часов уведомлений">
          <HoursForm settings={gym.settings} onSaved={() => go(2)} submitLabel="Сохранить и дальше" />
        </StepCard>
      ) : null}

      {step === 2 && gym ? (
        <StepCard title="Зоны зала" description="Тренажёрный зал, сауна, дорожки, студия — для расписания и брони. Можно пропустить.">
          <ZonesEditor zones={zones} />
          <Nav onBack={() => go(1)} onNext={() => go(3)} />
        </StepCard>
      ) : null}

      {step === 3 && gym ? <PlansStep plans={plans} onBack={() => go(2)} onNext={() => go(4)} /> : null}

      {step === 4 && gym ? (
        <StepCard title="Пригласите сотрудников" description="Администраторы и ресепшен получат письмо со ссылкой. Можно сделать позже в разделе «Сотрудники».">
          <InviteForm compact onDone={() => router.refresh()} />
          <ul className="grid gap-1 text-sm">
            {staff.map((s) => <li key={s.id} className="flex justify-between rounded-2xl bg-field px-3 py-2"><span>{s.full_name} · {s.email}</span><span className="text-muted-foreground">{t(ROLE_LABEL[s.role as Role])}</span></li>)}
          </ul>
          <Nav onBack={() => go(3)} onNext={() => go(5)} />
        </StepCard>
      ) : null}

      {step === 5 && gym ? <FinishStep /> : null}
    </div>
  );
}

function CreateGymStep({ email }: { email: string }) {
  const t = useT();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <StepCard title="Расскажите о зале" description={t("Вы входите как {email}. Настройка займёт около 15 минут.", { email })}>
      <form className="grid gap-4" action={(f) => start(async () => {
        const r = await createGym(f);
        if (!r.ok) return setError(r.error.message);
        router.push("/onboarding?step=1");
        router.refresh();
      })}>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Название зала"><Input name="name" required placeholder="Iron Gym" /></Field>
          <Field label="Ваше имя"><Input name="owner_name" required placeholder="Анна Смирнова" /></Field>
          <Field label="Адрес"><Input name="address" placeholder="Москва, ул. Спортивная, 1" /></Field>
          <Field label="Телефон зала"><Input name="phone" type="tel" /></Field>
          <Field label="Часовой пояс">
            <NativeSelect name="timezone" defaultValue="Europe/Moscow">{TIMEZONES.map(([v, l]) => <option key={v} value={v}>{t(l)}</option>)}</NativeSelect>
          </Field>
        </div>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <div><Button type="submit" size="lg" disabled={pending}>{pending ? t("Создаём…") : t("Создать зал")}</Button></div>
      </form>
    </StepCard>
  );
}

function PlansStep({ plans, onBack, onNext }: { plans: Plan[]; onBack: () => void; onNext: () => void }) {
  const tr = useT();
  const router = useRouter();
  const [dialog, setDialog] = useState(false);
  const [pending, start] = useTransition();
  const existing = new Set(plans.map((p) => p.name));
  return (
    <StepCard title="Тарифы" description="Добавьте готовые шаблоны и поправьте цены или создайте свои. Цены можно менять в любой момент.">
      <div className="flex flex-wrap gap-2">
        {TEMPLATES.map((t) => ({ ...t, name: tr(t.name) })).filter((t) => !existing.has(t.name)).map((t) => (
          <Button key={t.name} variant="outline" size="sm" disabled={pending} onClick={() => start(async () => {
            const r = await createTemplatePlans([t]);
            if (!r.ok) toast.error(r.error.message); else router.refresh();
          })}><Plus /> {t.name} · {money(t.price)}</Button>
        ))}
        <Button size="sm" onClick={() => setDialog(true)}><Plus /> Свой тариф</Button>
      </div>
      {plans.length ? (
        <ul className="grid gap-2">
          {plans.map((p) => (
            <li key={p.id} className="flex items-center justify-between rounded-2xl bg-field px-4 py-3">
              <span><b>{p.name}</b> <span className="text-sm text-muted-foreground">· {tr(PLAN_KIND_LABEL[p.kind])} · {p.duration_days} {tr("дн.")}{p.visits_limit ? ` · ${p.visits_limit} ${tr("виз.")}` : ""}</span></span>
              <span className="font-semibold tabular">{money(p.price)}</span>
            </li>
          ))}
        </ul>
      ) : <p className="text-sm text-muted-foreground">{tr("Пока ни одного тарифа.")}</p>}
      <Nav onBack={onBack} onNext={onNext} nextDisabled={plans.length === 0} nextHint={plans.length === 0 ? "Добавьте хотя бы один тариф" : undefined} />
      {dialog ? <PlanDialog plan={null} onClose={() => { setDialog(false); router.refresh(); }} /> : null}
    </StepCard>
  );
}

function FinishStep() {
  const t = useT();
  const router = useRouter();
  const [pending, start] = useTransition();
  const finish = (to: string) => start(async () => {
    const r = await finishOnboarding();
    if (!r.ok) return void toast.error(r.error.message);
    router.push(to);
    router.refresh();
  });
  return (
    <StepCard title="Всё готово!" description="Осталось перенести клиентов. Загрузите Excel из текущей таблицы — телефоны и даты мы разберём сами.">
      <div className="flex flex-wrap gap-2">
        <Button size="lg" onClick={() => finish("/clients/import")} disabled={pending}>Импортировать клиентов</Button>
        <Button size="lg" variant="outline" onClick={() => finish("/dashboard")} disabled={pending}>Перейти в кабинет</Button>
      </div>
      <p className="text-sm text-muted-foreground">{t("Позже всё можно изменить в разделе")} <Link href="/settings" className="underline">{t("Настройки зала")}</Link>.</p>
    </StepCard>
  );
}

function StepCard({ title, description, children }: { title: string; description?: string; children: React.ReactNode }) {
  return (
    <Card>
      <CardHeader><CardTitle className="text-xl">{title}</CardTitle>{description ? <CardDescription>{description}</CardDescription> : null}</CardHeader>
      <CardContent className="grid gap-5">{children}</CardContent>
    </Card>
  );
}

function Nav({ onBack, onNext, nextDisabled, nextHint }: { onBack: () => void; onNext: () => void; nextDisabled?: boolean; nextHint?: string }) {
  const t = useT();
  return (
    <div className="flex items-center justify-between gap-2 border-t border-border pt-4">
      <Button variant="ghost" onClick={onBack}>Назад</Button>
      <div className="flex items-center gap-3">
        {nextHint ? <span className="text-xs text-muted-foreground">{t(nextHint)}</span> : null}
        <Button onClick={onNext} disabled={nextDisabled}>Дальше</Button>
      </div>
    </div>
  );
}
