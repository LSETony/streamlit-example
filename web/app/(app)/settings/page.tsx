import type { Metadata } from "next";
import { PageHeader } from "@/components/app-shell";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { HoursForm, ProfileForm, RiskForm, RulesForm, ZonesEditor } from "@/components/gym-settings-forms";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { yookassaStatus } from "@/app/actions/gym";
import { date } from "@/lib/format";
import { YookassaForm } from "./yookassa-form";

export const metadata: Metadata = { title: "Настройки зала" };

const PLAN_LABEL = { start: "Старт", business: "Бизнес", network: "Сеть" } as const;

export default async function SettingsPage() {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const [{ data: zones }, yk] = await Promise.all([
    supabase.from("zones").select("id, name, capacity").eq("gym_id", ctx.gym.id).order("name"),
    yookassaStatus(),
  ]);
  const g = ctx.gym;
  const paid = g.paid_until && g.paid_until >= ctx.today;
  return (
    <>
      <PageHeader title="Настройки зала" />
      <div className="grid gap-6">
        <Section title="Подписка core." description="Тариф и оплата подписки ведутся командой core.">
          <div className="flex flex-wrap items-center gap-3 text-sm">
            <Badge variant="brand">Тариф «{PLAN_LABEL[g.core_plan]}»</Badge>
            {paid ? <span>Оплачено до {date(g.paid_until)}</span>
              : g.trial_until >= ctx.today ? <span>Пробный период до {date(g.trial_until)}</span>
              : <Badge variant="danger">Пробный период закончился — режим «только чтение»</Badge>}
          </div>
        </Section>
        <Section title="Зал"><ProfileForm gym={g} disabled={ctx.readOnly} /></Section>
        <Section title="Часы работы и вместимость"><HoursForm settings={g.settings} disabled={ctx.readOnly} /></Section>
        <Section title="Зоны" description="Зал, сауна, дорожки, пилатес — для расписания и брони"><ZonesEditor zones={zones ?? []} disabled={ctx.readOnly} /></Section>
        <Section title="Правила"><RulesForm settings={g.settings} disabled={ctx.readOnly} /></Section>
        <Section title="«В зоне риска»" description="Пороги попадания в список и шаблоны сообщений"><RiskForm settings={g.settings} disabled={ctx.readOnly} /></Section>
        <Section title="Онлайн-оплата ЮKassa" description="Деньги поступают напрямую на счёт зала. Ключ хранится в зашифрованном виде только на сервере.">
          <YookassaForm status={yk} disabled={ctx.readOnly} />
        </Section>
      </div>
    </>
  );
}

function Section({ title, description, children }: { title: string; description?: string; children: React.ReactNode }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {description ? <CardDescription>{description}</CardDescription> : null}
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}
