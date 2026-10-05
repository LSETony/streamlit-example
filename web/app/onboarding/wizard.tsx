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
import { HoursForm, TIMEZONES_BY_REGION, ZonesEditor } from "@/components/gym-settings-forms";
import { createGym, finishOnboarding } from "@/app/actions/gym";
import { createTemplatePlans } from "@/app/actions/plans";
import { PlanDialog } from "@/app/(app)/plans/plans-manager";
import { InviteForm } from "@/app/(app)/staff/staff-manager";
import type { Gym, Plan } from "@/lib/types";
import { PLAN_KIND_LABEL, ROLE_LABEL, type Role } from "@/lib/types";
import { cn } from "@/lib/utils";
import { useT } from "@/lib/i18n/client";
import { setLocale } from "@/app/actions/locale";
import { PLAN_TEMPLATE_PRICES, REGIONS, type Region } from "@/lib/region";
import { useRegion } from "@/lib/region-context";

const STEPS = ["Зал", "Часы работы", "Зоны", "Тарифы", "Сотрудники", "Готово"];

function templates(region: Region) {
  const p = PLAN_TEMPLATE_PRICES[region];
  const online = REGIONS[region].onlinePayments;
  return [
    { name: "Разовое посещение", kind: "visits" as const, price: p.single, duration_days: 1, visits_limit: 1, freeze_days_max: 0, sold_online: online },
    { name: "Месяц", kind: "unlimited" as const, price: p.month, duration_days: 30, visits_limit: null, freeze_days_max: 7, sold_online: online },
    { name: "8 занятий", kind: "visits" as const, price: p.pack8, duration_days: 45, visits_limit: 8, freeze_days_max: 7, sold_online: online },
    { name: "3 месяца", kind: "unlimited" as const, price: p.quarter, duration_days: 90, visits_limit: null, freeze_days_max: 14, sold_online: online },
    { name: "Год", kind: "unlimited" as const, price: p.year, duration_days: 365, visits_limit: null, freeze_days_max: 30, sold_online: false },
  ];
}

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
  const [region, setRegion] = useState<Region | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  // Регион сразу переключает язык кабинета: Россия — русский, ОАЭ — английский (сменить можно в меню профиля)
  const choose = (r: Region) => {
    setRegion(r);
    const lang = REGIONS[r].locale;
    if (lang !== t.locale) {
      document.documentElement.lang = lang;
      void setLocale(lang).then(() => router.refresh());
    }
  };

  if (!region) {
    return (
      <StepCard title="Где работает ваш зал?" description={t("От региона зависят валюта, формат телефонов, часовой пояс и язык кабинета. Изменить его после создания зала нельзя.")}>
        <div className="grid gap-3 sm:grid-cols-2">
          <RegionCard flag={<FlagRU />} title="Россия" hint="Рубли · +7 · ЮKassa · русский язык" onClick={() => choose("RU")} />
          <RegionCard flag={<FlagAE />} title="ОАЭ" hint="Дирхамы (AED) · +971 · английский язык" onClick={() => choose("AE")} />
        </div>
      </StepCard>
    );
  }

  const info = REGIONS[region];
  return (
    <StepCard title="Расскажите о зале" description={t("Вы входите как {email}. Настройка займёт около 15 минут.", { email })}>
      <div className="flex items-center justify-between gap-3 rounded-2xl bg-field px-4 py-3">
        <span className="flex items-center gap-3 text-[15px]">
          {region === "RU" ? <FlagRU /> : <FlagAE />}
          <span><b>{t(region === "RU" ? "Россия" : "ОАЭ")}</b> <span className="text-muted-foreground">· {info.currency} · {info.phoneCode}</span></span>
        </span>
        <Button type="button" variant="ghost" size="sm" onClick={() => setRegion(null)}>Изменить</Button>
      </div>
      <form className="grid gap-4" action={(f) => start(async () => {
        const r = await createGym(f);
        if (!r.ok) return setError(r.error.message);
        router.push("/onboarding?step=1");
        router.refresh();
      })}>
        <input type="hidden" name="region" value={region} />
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Название зала"><Input name="name" required placeholder="Iron Gym" /></Field>
          <Field label="Ваше имя"><Input name="owner_name" required placeholder={region === "AE" ? "Sarah Ahmed" : "Анна Смирнова"} /></Field>
          <Field label="Адрес"><Input name="address" placeholder={region === "AE" ? "Al Quoz 1, Dubai" : "Москва, ул. Спортивная, 1"} /></Field>
          <Field label="Телефон зала"><Input name="phone" type="tel" placeholder={info.phonePlaceholder} /></Field>
          <Field label="Часовой пояс">
            <NativeSelect key={region} name="timezone" defaultValue={info.timezone}>{TIMEZONES_BY_REGION[region].map(([v, l]) => <option key={v} value={v}>{l}</option>)}</NativeSelect>
          </Field>
        </div>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <div><Button type="submit" size="lg" disabled={pending}>{pending ? t("Создаём…") : t("Создать зал")}</Button></div>
      </form>
    </StepCard>
  );
}

function RegionCard({ flag, title, hint, onClick }: { flag: React.ReactNode; title: string; hint: string; onClick: () => void }) {
  const t = useT();
  return (
    <button type="button" onClick={onClick}
      className="flex cursor-pointer items-center gap-4 rounded-[22px] bg-field p-5 text-left transition-colors hover:bg-tint-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/50 active:scale-[0.99]">
      <span className="shrink-0 overflow-hidden rounded-lg shadow-sm">{flag}</span>
      <span className="grid gap-1">
        <span className="text-[19px] font-semibold">{t(title)}</span>
        <span className="text-sm text-muted-foreground">{t(hint)}</span>
      </span>
    </button>
  );
}

function FlagRU() {
  return (
    <svg viewBox="0 0 9 6" className="h-7 w-[42px]" aria-hidden>
      <rect width="9" height="2" fill="#fff" /><rect y="2" width="9" height="2" fill="#0039A6" /><rect y="4" width="9" height="2" fill="#D52B1E" />
      <rect width="9" height="6" fill="none" stroke="rgba(0,0,0,.12)" strokeWidth=".15" />
    </svg>
  );
}

function FlagAE() {
  return (
    <svg viewBox="0 0 12 6" className="h-7 w-[42px]" aria-hidden>
      <rect width="12" height="2" fill="#00732F" /><rect y="2" width="12" height="2" fill="#fff" /><rect y="4" width="12" height="2" fill="#000" />
      <rect width="3" height="6" fill="#FF0000" />
    </svg>
  );
}

function PlansStep({ plans, onBack, onNext }: { plans: Plan[]; onBack: () => void; onNext: () => void }) {
  const tr = useT();
  const { region, money } = useRegion();
  const router = useRouter();
  const [dialog, setDialog] = useState(false);
  const [pending, start] = useTransition();
  const existing = new Set(plans.map((p) => p.name));
  return (
    <StepCard title="Тарифы" description="Добавьте готовые шаблоны и поправьте цены или создайте свои. Цены можно менять в любой момент.">
      <div className="flex flex-wrap gap-2">
        {templates(region).map((t) => ({ ...t, name: tr(t.name) })).filter((t) => !existing.has(t.name)).map((t) => (
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
