"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Trash2, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox, Field, Input, NativeSelect, Textarea } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { deleteZone, saveZone, updateGymProfile, updateGymSettings } from "@/app/actions/gym";
import type { Gym, GymSettings, RiskReason } from "@/lib/types";
import { RISK_LABEL } from "@/lib/types";

export const TIMEZONES = [
  ["Europe/Kaliningrad", "Калининград (UTC+2)"], ["Europe/Moscow", "Москва (UTC+3)"], ["Europe/Samara", "Самара (UTC+4)"],
  ["Asia/Yekaterinburg", "Екатеринбург (UTC+5)"], ["Asia/Omsk", "Омск (UTC+6)"], ["Asia/Novosibirsk", "Новосибирск (UTC+7)"],
  ["Asia/Krasnoyarsk", "Красноярск (UTC+7)"], ["Asia/Irkutsk", "Иркутск (UTC+8)"], ["Asia/Yakutsk", "Якутск (UTC+9)"],
  ["Asia/Vladivostok", "Владивосток (UTC+10)"], ["Asia/Magadan", "Магадан (UTC+11)"], ["Asia/Kamchatka", "Камчатка (UTC+12)"],
] as const;

const DAYS: [string, string][] = [["mon", "Пн"], ["tue", "Вт"], ["wed", "Ср"], ["thu", "Чт"], ["fri", "Пт"], ["sat", "Сб"], ["sun", "Вс"]];

function useSave() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const run = (fn: () => Promise<{ ok: boolean; error?: { message: string } }>, msg = "Сохранено", after?: () => void) => start(async () => {
    setError(null);
    const r = await fn();
    if (!r.ok) return setError(r.error!.message);
    toast.success(msg);
    after?.();
    router.refresh();
  });
  return { pending, error, run };
}

export function ProfileForm({ gym, disabled }: { gym: Gym; disabled?: boolean }) {
  const { pending, error, run } = useSave();
  return (
    <form className="grid gap-4" action={(f) => run(() => updateGymProfile(f))}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Название зала"><Input name="name" defaultValue={gym.name} required /></Field>
        <Field label="Телефон"><Input name="phone" type="tel" defaultValue={gym.phone ?? ""} /></Field>
        <Field label="Адрес"><Input name="address" defaultValue={gym.address ?? ""} /></Field>
        <Field label="Часовой пояс">
          <NativeSelect name="timezone" defaultValue={gym.timezone}>
            {TIMEZONES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </NativeSelect>
        </Field>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button type="submit" disabled={pending || disabled}>Сохранить</Button></div>
    </form>
  );
}

export function HoursForm({ settings, disabled, onSaved, submitLabel = "Сохранить" }: { settings: GymSettings; disabled?: boolean; onSaved?: () => void; submitLabel?: string }) {
  const { pending, error, run } = useSave();
  const [hours, setHours] = useState(settings.hours ?? {});
  const [capacity, setCapacity] = useState(String(settings.capacity ?? 50));
  return (
    <div className="grid gap-4">
      <div className="grid gap-2">
        {DAYS.map(([k, label]) => {
          const v = hours[k];
          return (
            <div key={k} className="grid grid-cols-[40px_1fr] items-center gap-3 sm:grid-cols-[40px_140px_1fr]">
              <span className="text-sm font-medium">{label}</span>
              <label className="flex items-center gap-2 text-sm">
                <input type="checkbox" className="size-4" checked={!!v} onChange={(e) => setHours((h) => ({ ...h, [k]: e.target.checked ? ["08:00", "22:00"] : null }))} />
                {v ? "Открыто" : "Выходной"}
              </label>
              {v ? (
                <div className="col-span-2 flex items-center gap-2 sm:col-span-1">
                  <Input type="time" value={v[0]} onChange={(e) => setHours((h) => ({ ...h, [k]: [e.target.value, v[1]] }))} className="w-32" aria-label={`${label}: открытие`} />
                  <span className="text-muted-foreground">—</span>
                  <Input type="time" value={v[1]} onChange={(e) => setHours((h) => ({ ...h, [k]: [v[0], e.target.value] }))} className="w-32" aria-label={`${label}: закрытие`} />
                </div>
              ) : null}
            </div>
          );
        })}
      </div>
      <Field label="Вместимость зала, человек" hint="Для загруженности «сейчас в зале / вместимость»" className="max-w-xs">
        <Input type="number" min={1} value={capacity} onChange={(e) => setCapacity(e.target.value)} />
      </Field>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button disabled={pending || disabled} onClick={() => run(() => updateGymSettings({ hours, capacity: Number(capacity) || 0 }), "Сохранено", onSaved)}>{submitLabel}</Button></div>
    </div>
  );
}

export function RulesForm({ settings, disabled }: { settings: GymSettings; disabled?: boolean }) {
  const { pending, error, run } = useSave();
  return (
    <form className="grid gap-4" action={(f) => run(() => updateGymSettings({
      auto_checkout_hours: Number(f.get("auto_checkout_hours")) || 3,
      booking_cancel_hours: Number(f.get("booking_cancel_hours")) || 0,
      allow_app_freeze: f.get("allow_app_freeze") === "on",
      notify_fallback: String(f.get("notify_fallback")) as GymSettings["notify_fallback"],
    }))}>
      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="Автовыход из зала через, ч" hint="Если клиент не отметил выход"><Input name="auto_checkout_hours" type="number" min={1} max={24} defaultValue={settings.auto_checkout_hours ?? 3} /></Field>
        <Field label="Отмена записи клиентом не позднее, ч"><Input name="booking_cancel_hours" type="number" min={0} max={72} defaultValue={settings.booking_cancel_hours ?? 2} /></Field>
        <Field label="Клиентам без приложения отправлять">
          <NativeSelect name="notify_fallback" defaultValue={settings.notify_fallback ?? "sms"}>
            <option value="sms">SMS</option><option value="email">Email</option><option value="none">Ничего</option>
          </NativeSelect>
        </Field>
      </div>
      <Checkbox name="allow_app_freeze" defaultChecked={settings.allow_app_freeze ?? true} label="Клиенты могут сами заморозить абонемент в приложении (в пределах лимита тарифа)" />
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button type="submit" disabled={pending || disabled}>Сохранить</Button></div>
    </form>
  );
}

export function RiskForm({ settings, disabled }: { settings: GymSettings; disabled?: boolean }) {
  const { pending, error, run } = useSave();
  const r = settings.risk ?? { gone_days: 10, expiring_days: 7, declining_ratio: 0.5, not_renewed_days: 14 };
  const t = settings.message_templates ?? ({} as Record<RiskReason, string>);
  return (
    <form className="grid gap-4" action={(f) => run(() => updateGymSettings({
      risk: {
        gone_days: Number(f.get("gone_days")) || 10,
        expiring_days: Number(f.get("expiring_days")) || 7,
        declining_ratio: (Number(f.get("declining_pct")) || 50) / 100,
        not_renewed_days: Number(f.get("not_renewed_days")) || 14,
      },
      message_templates: {
        gone: String(f.get("tpl_gone")), expiring: String(f.get("tpl_expiring")),
        declining: String(f.get("tpl_declining")), not_renewed: String(f.get("tpl_not_renewed")),
      },
    }))}>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Field label="«Пропал»: нет визитов, дней"><Input name="gone_days" type="number" min={3} max={60} defaultValue={r.gone_days} /></Field>
        <Field label="«Заканчивается»: осталось дней"><Input name="expiring_days" type="number" min={1} max={30} defaultValue={r.expiring_days} /></Field>
        <Field label="«Реже»: доля от обычного, %"><Input name="declining_pct" type="number" min={10} max={90} defaultValue={Math.round(r.declining_ratio * 100)} /></Field>
        <Field label="«Не продлил»: дней после окончания"><Input name="not_renewed_days" type="number" min={3} max={60} defaultValue={r.not_renewed_days} /></Field>
      </div>
      <p className="text-sm text-muted-foreground">Шаблоны сообщений для Telegram и WhatsApp. Подстановки: {"{name}"} — имя, {"{gym}"} — зал, {"{date}"} — дата окончания.</p>
      <div className="grid gap-4 lg:grid-cols-2">
        {(["gone", "expiring", "declining", "not_renewed"] as RiskReason[]).map((k) => (
          <Field key={k} label={RISK_LABEL[k]}><Textarea name={`tpl_${k}`} rows={2} defaultValue={t[k] ?? ""} /></Field>
        ))}
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button type="submit" disabled={pending || disabled}>Сохранить</Button></div>
    </form>
  );
}

export function ZonesEditor({ zones, disabled }: { zones: { id: string; name: string; capacity: number }[]; disabled?: boolean }) {
  const { pending, error, run } = useSave();
  const [name, setName] = useState("");
  const [capacity, setCapacity] = useState("10");
  return (
    <div className="grid gap-3">
      {zones.map((z) => (
        <form key={z.id} className="flex flex-wrap items-center gap-2" action={(f) => run(() => saveZone(f))}>
          <input type="hidden" name="id" value={z.id} />
          <Input name="name" defaultValue={z.name} className="max-w-xs flex-1" aria-label="Название зоны" />
          <Input name="capacity" type="number" min={1} defaultValue={z.capacity} className="w-24" aria-label="Вместимость" />
          <Button type="submit" variant="outline" size="sm" disabled={pending || disabled}>Сохранить</Button>
          <Button type="button" variant="ghost" size="icon-sm" aria-label="Удалить зону" disabled={pending || disabled} onClick={() => confirm(`Удалить зону «${z.name}»?`) && run(() => deleteZone(z.id), "Зона удалена")}><Trash2 /></Button>
        </form>
      ))}
      <div className="flex flex-wrap items-center gap-2">
        <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Тренажёрный зал, сауна, дорожки…" className="max-w-xs flex-1" aria-label="Новая зона" />
        <Input value={capacity} onChange={(e) => setCapacity(e.target.value)} type="number" min={1} className="w-24" aria-label="Вместимость" />
        <Button variant="outline" size="sm" disabled={pending || disabled || !name.trim()} onClick={() => {
          const f = new FormData();
          f.set("name", name);
          f.set("capacity", capacity);
          run(() => saveZone(f), "Зона добавлена", () => setName(""));
        }}><Plus /> Добавить</Button>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
    </div>
  );
}
