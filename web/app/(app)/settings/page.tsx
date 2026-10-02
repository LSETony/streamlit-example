import type { Metadata } from "next";
import { Clock, CreditCard, Crown, MapPin, ShieldAlert, SlidersHorizontal, Store } from "lucide-react";
import { PageHeader } from "@/components/app-shell";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { HoursForm, ProfileForm, RiskForm, RulesForm, ZonesEditor } from "@/components/gym-settings-forms";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { yookassaStatus } from "@/app/actions/gym";
import { date } from "@/lib/format";
import { YookassaForm } from "./yookassa-form";
import { getT } from "@/lib/i18n/server";
import type { T } from "@/lib/i18n/core";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Настройки зала") };
}

const PLAN_LABEL = { start: "Старт", business: "Бизнес", network: "Сеть" } as const;
const SECTIONS = [
  { id: "gym", title: "Зал", icon: Store },
  { id: "hours", title: "Часы работы", icon: Clock },
  { id: "zones", title: "Зоны", icon: MapPin },
  { id: "rules", title: "Правила", icon: SlidersHorizontal },
  { id: "risk", title: "«В зоне риска»", icon: ShieldAlert },
  { id: "payments", title: "Онлайн-оплата", icon: CreditCard },
] as const;

export default async function SettingsPage() {
  const ctx = await requireStaff(["owner"]);
  const supabase = await createClient();
  const [{ data: zones }, yk] = await Promise.all([
    supabase.from("zones").select("id, name, capacity").eq("gym_id", ctx.gym.id).order("name"),
    yookassaStatus(),
  ]);
  const t = await getT();
  const g = ctx.gym;
  const paid = g.paid_until && g.paid_until >= ctx.today;
  return (
    <>
      <PageHeader title="Настройки зала" description="Изменения сохраняются по разделам" />
      <div className="grid gap-8 lg:grid-cols-[200px_1fr]">
        <nav className="hidden lg:block" aria-label={t("Разделы настроек")}>
          <div className="sticky top-8 grid gap-0.5">
            {SECTIONS.map(({ id, title, icon: Icon }) => (
              <a key={id} href={`#${id}`} className="flex items-center gap-2.5 rounded-full px-4 py-2 text-sm text-muted-foreground transition-colors hover:bg-field hover:text-foreground">
                <Icon className="size-4" /> {t(title)}
              </a>
            ))}
          </div>
        </nav>

        <div className="grid min-w-0 gap-6">
          <Card className="flex flex-wrap items-center gap-4 bg-sidebar p-5 text-white">
            <span className="grid size-11 place-items-center rounded-xl bg-brand text-brand-foreground"><Crown className="size-5" /></span>
            <div className="grid flex-1 gap-0.5">
              <p className="font-semibold">{t("Подписка core. · тариф «{plan}»", { plan: t(PLAN_LABEL[g.core_plan]) })}</p>
              <p className="text-sm text-sidebar-foreground">
                {paid ? t("Оплачено до {date}", { date: date(g.paid_until) })
                  : g.trial_until >= ctx.today ? t("Пробный период до {date}", { date: date(g.trial_until) })
                  : t("Пробный период закончился — кабинет в режиме «только чтение»")}
              </p>
            </div>
            {paid || g.trial_until >= ctx.today ? <Badge variant="brand">Активна</Badge> : <Badge variant="danger">Только чтение</Badge>}
          </Card>

          <Section t={t} id="gym" title="Зал" description="Название и часовой пояс видят клиенты в приложении">
            <ProfileForm gym={g} disabled={ctx.readOnly} />
          </Section>
          <Section t={t} id="hours" title="Часы работы и вместимость" description="Нужны для расписания, тепловой карты и «тихих часов» уведомлений">
            <HoursForm settings={g.settings} disabled={ctx.readOnly} />
          </Section>
          <Section t={t} id="zones" title="Зоны" description="Зал, сауна, дорожки, студия — для расписания и брони">
            <ZonesEditor zones={zones ?? []} disabled={ctx.readOnly} />
          </Section>
          <Section t={t} id="rules" title="Правила"><RulesForm settings={g.settings} disabled={ctx.readOnly} /></Section>
          <Section t={t} id="risk" title="«В зоне риска»" description="Пороги попадания в список и шаблоны сообщений">
            <RiskForm settings={g.settings} disabled={ctx.readOnly} />
          </Section>
          <Section t={t} id="payments" title="Онлайн-оплата ЮKassa" description="Деньги поступают напрямую на счёт зала. Ключ хранится в зашифрованном виде только на сервере.">
            <YookassaForm status={yk} disabled={ctx.readOnly} />
          </Section>
        </div>
      </div>
    </>
  );
}

function Section({ t, id, title, description, children }: { t: T; id: string; title: string; description?: string; children: React.ReactNode }) {
  return (
    <Card id={id} className="scroll-mt-8">
      <div className="grid gap-1 border-b border-border px-6 py-5">
        <h2 className="text-base font-semibold tracking-tight">{t(title)}</h2>
        {description ? <p className="text-sm text-muted-foreground">{t(description)}</p> : null}
      </div>
      <div className="p-6">{children}</div>
    </Card>
  );
}
