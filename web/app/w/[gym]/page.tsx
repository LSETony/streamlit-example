import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { createClient } from "@supabase/supabase-js";
import { Logo } from "@/components/logo";
import type { ClassItem } from "@/components/class-list";
import { money, phone } from "@/lib/format";
import { getT } from "@/lib/i18n/server";
import { ANON_KEY, serverUrl } from "@/lib/supabase/config";
import { WidgetSchedule } from "./widget-schedule";

/*
  Виджет записи для сайта зала: <iframe src="/w/<id>">. Расписание со свободными местами и цены — без входа
  и без персональных данных; запись открывает приложение клиента (вход по телефону) в новой вкладке.
*/

interface PublicGym {
  id: string; name: string; address: string | null; phone: string | null; currency: string; timezone: string; schedule: boolean;
  plans: { id: string; name: string; description: string | null; kind: string; price: number; duration_days: number; visits_limit: number | null }[];
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function load(gymId: string) {
  if (!UUID_RE.test(gymId)) return null;
  const supabase = createClient(serverUrl(), ANON_KEY, { auth: { persistSession: false, autoRefreshToken: false } });
  const [{ data: gym }, { data: items }] = await Promise.all([
    supabase.rpc("public_gym", { p_gym: gymId }),
    supabase.rpc("public_schedule", { p_gym: gymId, p_days: 14 }),
  ]);
  if (!gym) return null;
  return { gym: gym as PublicGym, items: (items as ClassItem[]) ?? [] };
}

export async function generateMetadata({ params }: PageProps<"/w/[gym]">): Promise<Metadata> {
  const data = await load((await params).gym);
  const t = await getT();
  return { title: { absolute: data ? t("Расписание — {gym}", { gym: data.gym.name }) : "core." } };
}

export default async function WidgetPage({ params, searchParams }: PageProps<"/w/[gym]">) {
  const { gym: gymId } = await params;
  const sp = await searchParams;
  const data = await load(gymId);
  if (!data) notFound();
  const t = await getT();
  const { gym, items } = data;
  const showPlans = sp.plans !== "0" && gym.plans.length > 0;
  return (
    <div className="mx-auto grid max-w-2xl gap-6 p-4 sm:p-6">
      <header className="grid gap-1">
        <h1 className="text-2xl font-bold tracking-tight">{gym.name}</h1>
        {gym.address && <p className="text-sm text-muted-foreground">{gym.address}</p>}
      </header>
      {gym.schedule && (
        <section className="grid gap-3">
          <h2 className="text-lg font-semibold">{t("Расписание")}</h2>
          {items.length ? <WidgetSchedule items={items} tz={gym.timezone} gymId={gym.id} />
            : <p className="text-sm text-muted-foreground">{t("В ближайшие две недели занятий нет")}</p>}
        </section>
      )}
      {showPlans && (
        <section className="grid gap-3">
          <h2 className="text-lg font-semibold">{t("Абонементы")}</h2>
          <div className="grid gap-2 sm:grid-cols-2">
            {gym.plans.map((p) => (
              <div key={p.id} className="grid gap-1 rounded-3xl bg-card p-4">
                <p className="font-semibold">{p.name}</p>
                <p className="text-xl font-bold tabular">{money(p.price, gym.currency)}</p>
                <p className="text-sm text-muted-foreground">
                  {p.visits_limit ? t("{n} посещений", { n: p.visits_limit }) + " · " : ""}{t("{n} дн.", { n: p.duration_days })}
                </p>
                {p.description && <p className="text-sm text-muted-foreground">{p.description}</p>}
              </div>
            ))}
          </div>
        </section>
      )}
      <footer className="flex items-center justify-between gap-3 text-xs text-muted-foreground">
        <span>{gym.phone ? <a href={`tel:${gym.phone}`}>{phone(gym.phone)}</a> : null}</span>
        <span className="flex items-center gap-1.5">{t("Работает на")} <Logo className="h-3.5" /></span>
      </footer>
    </div>
  );
}
