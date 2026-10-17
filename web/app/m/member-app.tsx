"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import QRCode from "qrcode";
import { CalendarDays, CreditCard, QrCode, Snowflake, UserRound } from "lucide-react";
import { deleteMemberAccount } from "@/app/actions/member";
import { LanguageSwitch } from "@/components/language-switch";
import { Logo } from "@/components/logo";
import { ClassList, type ClassItem } from "@/components/class-list";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/misc";
import { toAppError } from "@/lib/errors";
import { addDays, date, phone as formatPhone, todayIn } from "@/lib/format";
import { useT } from "@/lib/i18n/client";
import { normalizePhone } from "@/lib/phone";
import { buildQrPayload, QR_PERIOD_SECONDS } from "@/lib/qr";
import { createClient } from "@/lib/supabase/client";
import { toast } from "@/lib/toast";
import { cn } from "@/lib/utils";

/*
  Приложение клиента зала в браузере (устанавливается на экран «Домой»): вход по SMS-коду, динамический QR-пропуск,
  абонементы с заморозкой, запись на занятия. Работает напрямую с БД от имени клиента — RLS показывает только его данные.
*/

interface LinkedClient { client_id: string; gym_id: string; gym_name: string; full_name: string }
interface Gym { id: string; name: string; address: string | null; phone: string | null; region: string; currency: string; timezone: string; schedule: boolean }
interface Membership {
  id: string; plan_name: string; kind: "period" | "visits" | "unlimited"; status: "pending" | "active" | "frozen" | "expired" | "cancelled";
  starts_on: string; ends_on: string; visits_left: number | null; freeze_days_max: number; freeze_days_used: number;
}

const DEVICE_KEY = "core-member-device";
const CLIENT_KEY = "core-member-client";

interface Loaded { state: "signed-out" | "staff" | "ready"; userId?: string; clients?: LinkedClient[]; clientId?: string | null }

function store(key: string): string | null {
  try { return localStorage.getItem(key); } catch { return null; }
}
function save(key: string, value: string | null) {
  try { if (value === null) localStorage.removeItem(key); else localStorage.setItem(key, value); } catch { /* приватный режим */ }
}

export function MemberApp({ joinGym }: { joinGym: string | null }) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [state, setState] = useState<"loading" | "signed-out" | "staff" | "ready">("loading");
  const [userId, setUserId] = useState<string | null>(null);
  const [clients, setClients] = useState<LinkedClient[]>([]);
  const [clientId, setClientId] = useState<string | null>(null);

  // загрузка состояния без setState до первого await — значения применяются одним вызовом apply
  const resolve = useCallback(async (): Promise<Loaded> => {
    const { data } = await supabase.auth.getUser();
    if (!data.user) return { state: "signed-out" };
    if (!data.user.phone) return { state: "staff" };
    const { data: linked, error } = await supabase.rpc("link_account");
    if (error) {
      toast.error(toAppError(error).message);
      return { state: "signed-out" };
    }
    const list = (linked as { clients: LinkedClient[] }).clients;
    const saved = store(CLIENT_KEY);
    const preferred = list.find((c) => c.gym_id === joinGym) ?? list.find((c) => c.client_id === saved) ?? list[0];
    return { state: "ready", userId: data.user.id, clients: list, clientId: preferred?.client_id ?? null };
  }, [supabase, joinGym]);

  const apply = (r: Loaded) => {
    setUserId(r.userId ?? null);
    setClients(r.clients ?? []);
    setClientId(r.clientId ?? null);
    setState(r.state);
  };
  const load = () => void resolve().then(apply);

  useEffect(() => { void resolve().then(apply); }, [resolve]);

  const signOut = async () => {
    await supabase.auth.signOut();
    save(DEVICE_KEY, null);
    save(CLIENT_KEY, null);
    setClients([]);
    setState("signed-out");
  };

  const current = clients.find((c) => c.client_id === clientId) ?? null;

  if (state === "loading") return <div className="grid gap-4 p-6"><Skeleton className="h-10 w-32" /><Skeleton className="h-80 rounded-3xl" /></div>;
  if (state === "signed-out") return <PhoneLogin onDone={load} />;
  if (state === "staff") {
    return (
      <Screen>
        <div className="grid gap-4 rounded-3xl bg-card p-6">
          <p className="text-lg font-semibold">{t("Вы вошли как сотрудник зала")}</p>
          <p className="text-sm text-muted-foreground">{t("Приложение клиента открывается по номеру телефона. Выйдите, чтобы войти как клиент.")}</p>
          <div className="flex gap-2">
            <Button onClick={signOut}>{t("Выйти")}</Button>
            <Button variant="outline" asChild><Link href="/">{t("В кабинет")}</Link></Button>
          </div>
        </div>
      </Screen>
    );
  }
  if (!current) return <JoinGym preselect={joinGym} onJoined={load} onSignOut={signOut} />;

  return (
    <MemberHome
      key={current.client_id}
      client={current}
      clients={clients}
      userId={userId!}
      onSwitch={(id) => { setClientId(id); save(CLIENT_KEY, id); }}
      onSignOut={signOut}
    />
  );
}

function Screen({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-dvh flex-col gap-6 px-5 pb-10 pt-[max(env(safe-area-inset-top),1.5rem)]">
      <div className="flex items-center justify-between">
        <Logo className="h-7" />
        <LanguageSwitch />
      </div>
      {children}
    </div>
  );
}

// ── Вход по номеру телефона ─────────────────────────────────────────
function PhoneLogin({ onDone }: { onDone: () => void }) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [phone, setPhone] = useState("");
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [busy, setBusy] = useState(false);

  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    const normalized = normalizePhone(phone);
    if (!normalized) return void toast.error("Некорректный номер телефона");
    setBusy(true);
    const { error } = await supabase.auth.signInWithOtp({ phone: normalized });
    setBusy(false);
    if (error) return void toast.error(error.message);
    setSentTo(normalized);
  };

  const verify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!sentTo) return;
    setBusy(true);
    const { error } = await supabase.auth.verifyOtp({ phone: sentTo, token: code.trim(), type: "sms" });
    setBusy(false);
    if (error) return void toast.error("Неверный или устаревший код");
    onDone();
  };

  return (
    <Screen>
      <div className="grid gap-2 pt-6">
        <h1 className="text-[34px] font-bold leading-tight tracking-tight">{t("Мой зал")}</h1>
        <p className="text-muted-foreground">{t("Пропуск, абонементы и запись на занятия. Войдите по номеру телефона, который вы оставили в зале.")}</p>
      </div>
      {!sentTo ? (
        <form onSubmit={send} className="grid gap-4">
          <Field label="Телефон">
            <Input type="tel" inputMode="tel" autoComplete="tel" value={phone} onChange={(e) => setPhone(e.target.value)}
              placeholder={t.locale === "en" ? "+971 50 123 4567" : "+7 916 123-45-67"} required autoFocus />
          </Field>
          <Button type="submit" size="lg" disabled={busy}>{t("Получить код")}</Button>
        </form>
      ) : (
        <form onSubmit={verify} className="grid gap-4">
          <Field label="Код из SMS" hint={t("Отправили на {phone}", { phone: formatPhone(sentTo) })}>
            <Input inputMode="numeric" autoComplete="one-time-code" value={code} onChange={(e) => setCode(e.target.value)}
              placeholder="123456" maxLength={6} required autoFocus className="text-center text-2xl tracking-[0.4em] tabular" />
          </Field>
          <Button type="submit" size="lg" disabled={busy}>{t("Войти")}</Button>
          <Button type="button" variant="ghost" onClick={() => { setSentTo(null); setCode(""); }}>{t("Изменить номер")}</Button>
        </form>
      )}
      <p className="mt-auto flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
        <a href="/terms" className="hover:text-foreground">{t("Условия использования")}</a>
        <a href="/privacy" className="hover:text-foreground">{t("Политика конфиденциальности")}</a>
      </p>
    </Screen>
  );
}

// ── Выбор зала, если номер ещё не записан ни в одном зале ─────────
function JoinGym({ preselect, onJoined, onSignOut }: { preselect: string | null; onJoined: () => void; onSignOut: () => void }) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [query, setQuery] = useState("");
  const [gyms, setGyms] = useState<{ id: string; name: string; address: string | null }[]>([]);
  const [picked, setPicked] = useState<string | null>(preselect);
  const [name, setName] = useState("");
  const [consent, setConsent] = useState(false);
  const [marketing, setMarketing] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const id = setTimeout(async () => {
      let q = supabase.from("public_gyms").select("id,name,address").order("name").limit(20);
      if (query.trim()) q = q.ilike("name", `%${query.trim()}%`);
      if (preselect && !query.trim()) q = q.eq("id", preselect);
      const { data } = await q;
      setGyms(data ?? []);
    }, 250);
    return () => clearTimeout(id);
  }, [supabase, query, preselect]);

  const join = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!picked) return;
    setBusy(true);
    const { error } = await supabase.rpc("join_gym", { p_gym: picked, p_full_name: name.trim(), p_marketing_consent: marketing });
    setBusy(false);
    if (error) return void toast.error(toAppError(error).message);
    onJoined();
  };

  return (
    <Screen>
      <div className="grid gap-2">
        <h1 className="text-[28px] font-bold leading-tight tracking-tight">{t("Выберите свой зал")}</h1>
        <p className="text-sm text-muted-foreground">{t("Мы не нашли ваш номер ни в одном зале. Выберите зал — он увидит вас в списке клиентов.")}</p>
      </div>
      <form onSubmit={join} className="grid gap-4">
        <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Поиск по названию" aria-label="Поиск по названию" />
        <div className="grid gap-2">
          {gyms.map((g) => (
            <button key={g.id} type="button" onClick={() => setPicked(g.id)}
              className={cn("cursor-pointer rounded-2xl border-2 bg-card px-4 py-3 text-left transition-colors",
                picked === g.id ? "border-tint" : "border-transparent")}>
              <span className="block font-semibold">{g.name}</span>
              {g.address && <span className="block text-sm text-muted-foreground">{g.address}</span>}
            </button>
          ))}
          {!gyms.length && <p className="text-sm text-muted-foreground">{t("Ничего не нашлось")}</p>}
        </div>
        <Field label="Имя и фамилия">
          <Input value={name} onChange={(e) => setName(e.target.value)} required minLength={2} autoComplete="name" />
        </Field>
        <Checkbox checked={consent} onChange={(e) => setConsent(e.target.checked)} required
          label={<>{t("Согласен на обработку персональных данных")} (<a href="/privacy" className="text-tint-text underline">{t("политика")}</a>)</>} />
        <Checkbox checked={marketing} onChange={(e) => setMarketing(e.target.checked)} label="Получать новости и акции зала" />
        <Button type="submit" size="lg" disabled={busy || !picked || !consent}>{t("Стать клиентом")}</Button>
        <Button type="button" variant="ghost" onClick={onSignOut}>{t("Выйти")}</Button>
      </form>
    </Screen>
  );
}

// ── Основной экран: пропуск, абонементы, расписание, профиль ─────
type Tab = "pass" | "memberships" | "schedule" | "profile";

function MemberHome({ client, clients, userId, onSwitch, onSignOut }: {
  client: LinkedClient; clients: LinkedClient[]; userId: string; onSwitch: (id: string) => void; onSignOut: () => void;
}) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [tab, setTab] = useState<Tab>("pass");
  const [gym, setGym] = useState<Gym | null>(null);
  const [memberships, setMemberships] = useState<Membership[] | null>(null);

  const fetchMemberships = useCallback(async () => {
    const { data } = await supabase.from("memberships")
      .select("id,plan_name,kind,status,starts_on,ends_on,visits_left,freeze_days_max,freeze_days_used")
      .eq("client_id", client.client_id).order("ends_on", { ascending: false });
    return (data as Membership[]) ?? [];
  }, [supabase, client.client_id]);
  const loadMemberships = () => void fetchMemberships().then(setMemberships);

  useEffect(() => {
    void supabase.rpc("public_gym", { p_gym: client.gym_id }).then(({ data }) => setGym(data as Gym));
    void fetchMemberships().then(setMemberships);
  }, [supabase, client.gym_id, fetchMemberships]);

  const tz = gym?.timezone ?? "Europe/Moscow";
  const today = todayIn(tz);
  const active = memberships?.find((m) => (m.status === "active" || m.status === "frozen") && m.ends_on >= today && m.starts_on <= today) ?? null;

  const tabs: { id: Tab; label: string; icon: React.ReactNode }[] = [
    { id: "pass", label: "Пропуск", icon: <QrCode /> },
    { id: "memberships", label: "Абонементы", icon: <CreditCard /> },
    ...(gym?.schedule !== false ? [{ id: "schedule" as Tab, label: "Расписание", icon: <CalendarDays /> }] : []),
    { id: "profile", label: "Профиль", icon: <UserRound /> },
  ];

  return (
    <div className="flex min-h-dvh flex-col">
      <header className="flex items-center justify-between gap-3 px-5 pb-2 pt-[max(env(safe-area-inset-top),1rem)]">
        <div className="min-w-0">
          <p className="truncate text-[13px] text-muted-foreground">{client.gym_name}</p>
          <p className="truncate text-xl font-bold tracking-tight">{t(tabs.find((x) => x.id === tab)?.label ?? "")}</p>
        </div>
        <Logo className="h-5 shrink-0 text-muted-foreground" />
      </header>
      <main className="flex-1 px-5 pb-28 pt-3">
        {tab === "pass" && <PassTab userId={userId} client={client} active={active} />}
        {tab === "memberships" && <MembershipsTab memberships={memberships} today={today} onChanged={loadMemberships} />}
        {tab === "schedule" && <ScheduleTab gymId={client.gym_id} tz={tz} />}
        {tab === "profile" && <ProfileTab client={client} clients={clients} gym={gym} onSwitch={onSwitch} onSignOut={onSignOut} />}
      </main>
      <nav className="fixed inset-x-0 bottom-0 z-20 mx-auto max-w-md border-t border-separator bg-background/85 pb-[env(safe-area-inset-bottom)] backdrop-blur-xl">
        <div className="grid" style={{ gridTemplateColumns: `repeat(${tabs.length}, 1fr)` }}>
          {tabs.map((x) => (
            <button key={x.id} type="button" onClick={() => setTab(x.id)} aria-current={tab === x.id ? "page" : undefined}
              className={cn("flex cursor-pointer flex-col items-center gap-0.5 py-2 text-[11px] font-medium [&_svg]:size-6",
                tab === x.id ? "text-tint-text" : "text-muted-foreground")}>
              {x.icon}
              {t(x.label)}
            </button>
          ))}
        </div>
      </nav>
    </div>
  );
}

// ── Пропуск: QR меняется каждые 30 секунд, скриншот не пройдёт ───
function PassTab({ userId, client, active }: { userId: string; client: LinkedClient; active: Membership | null }) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [device, setDevice] = useState<{ device_id: string; qr_secret: string } | null>(null);
  const [img, setImg] = useState<string | null>(null);
  const [left, setLeft] = useState(QR_PERIOD_SECONDS);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      let saved: { user_id: string; device_id: string } | null = null;
      try { saved = JSON.parse(store(DEVICE_KEY) ?? "null"); } catch { saved = null; }
      const { data, error } = await supabase.rpc("register_device", {
        p_platform: "web", p_push_token: null, p_device_id: saved?.user_id === userId ? saved.device_id : null,
      });
      if (cancelled) return;
      if (error) return void toast.error(toAppError(error).message);
      const d = data as { device_id: string; qr_secret: string };
      save(DEVICE_KEY, JSON.stringify({ user_id: userId, device_id: d.device_id }));
      setDevice(d);
    })();
    return () => { cancelled = true; };
  }, [supabase, userId]);

  useEffect(() => {
    if (!device) return;
    let period = -1;
    const tick = async () => {
      const now = Date.now();
      const p = Math.floor(now / 1000 / QR_PERIOD_SECONDS);
      setLeft(QR_PERIOD_SECONDS - (Math.floor(now / 1000) % QR_PERIOD_SECONDS));
      if (p === period) return;
      period = p;
      const payload = await buildQrPayload(device.device_id, device.qr_secret, now);
      setImg(await QRCode.toDataURL(payload, { margin: 1, width: 560, errorCorrectionLevel: "M" }));
    };
    void tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [device]);

  return (
    <div className="grid gap-4">
      <div className="grid justify-items-center gap-4 rounded-[28px] bg-card p-6 shadow-sm">
        <p className="text-lg font-semibold">{client.full_name}</p>
        <div className="relative aspect-square w-full max-w-[300px] rounded-2xl bg-white p-3">
          {/* eslint-disable-next-line @next/next/no-img-element -- QR-код из data: URL */}
          {img ? <img src={img} alt={t("QR-пропуск")} className="size-full" /> : <Skeleton className="size-full" />}
        </div>
        <div className="flex items-center gap-2 text-sm text-muted-foreground">
          <span className="relative block h-1.5 w-24 overflow-hidden rounded-full bg-field">
            <span className="absolute inset-y-0 left-0 rounded-full bg-tint transition-[width] duration-1000 ease-linear"
              style={{ width: `${(left / QR_PERIOD_SECONDS) * 100}%` }} />
          </span>
          {t("Обновится через {n} с", { n: left })}
        </div>
        <p className="text-center text-sm text-muted-foreground">{t("Покажите код на ресепшене или поднесите к сканеру")}</p>
      </div>
      <MembershipCard m={active} />
    </div>
  );
}

function MembershipCard({ m }: { m: Membership | null }) {
  const t = useT();
  if (!m) {
    return (
      <div className="rounded-3xl bg-card p-5">
        <p className="font-semibold">{t("Нет действующего абонемента")}</p>
        <p className="mt-1 text-sm text-muted-foreground">{t("Купить абонемент можно на ресепшене зала.")}</p>
      </div>
    );
  }
  return (
    <div className="grid gap-1 rounded-3xl bg-tint p-5 text-white">
      <p className="text-sm text-white/75">{m.status === "frozen" ? t("Заморожен") : t("Действует")}</p>
      <p className="text-xl font-bold">{m.plan_name}</p>
      <p className="text-sm text-white/85">
        {t("до {date}", { date: date(m.ends_on) })}
        {m.visits_left !== null && <> · {t("Осталось посещений: {n}", { n: m.visits_left })}</>}
      </p>
    </div>
  );
}

// ── Абонементы и заморозка ────────────────────────────────────────
const STATUS_TEXT: Record<Membership["status"], string> = {
  pending: "Ожидает оплаты", active: "Действует", frozen: "Заморожен", expired: "Истёк", cancelled: "Отменён",
};

function MembershipsTab({ memberships, today, onChanged }: { memberships: Membership[] | null; today: string; onChanged: () => void }) {
  const t = useT();
  const [freezing, setFreezing] = useState<Membership | null>(null);
  if (!memberships) return <Skeleton className="h-32 rounded-3xl" />;
  if (!memberships.length) return <MembershipCard m={null} />;
  return (
    <div className="grid gap-3">
      {memberships.map((m) => {
        const freezeLeft = m.freeze_days_max - m.freeze_days_used;
        const canFreeze = (m.status === "active" || m.status === "frozen") && m.ends_on >= today && freezeLeft > 0;
        return (
          <div key={m.id} className="grid gap-2 rounded-3xl bg-card p-5">
            <div className="flex items-start justify-between gap-3">
              <p className="font-semibold">{m.plan_name}</p>
              <span className={cn("rounded-full px-2.5 py-0.5 text-xs font-semibold",
                m.status === "active" ? "bg-success/15 text-success" : m.status === "frozen" ? "bg-tint-soft text-tint-text" : "bg-field text-muted-foreground")}>
                {t(STATUS_TEXT[m.status])}
              </span>
            </div>
            <p className="text-sm text-muted-foreground">{date(m.starts_on)} — {date(m.ends_on)}</p>
            {m.visits_left !== null && <p className="text-sm">{t("Осталось посещений: {n}", { n: m.visits_left })}</p>}
            {m.freeze_days_max > 0 && <p className="text-sm text-muted-foreground">{t("Заморозка: использовано {used} из {max} дн.", { used: m.freeze_days_used, max: m.freeze_days_max })}</p>}
            {canFreeze && (
              <Button variant="secondary" size="sm" className="justify-self-start" onClick={() => setFreezing(m)}>
                <Snowflake /> {t("Заморозить")}
              </Button>
            )}
          </div>
        );
      })}
      {freezing && <FreezeDialog m={freezing} today={today} onClose={() => setFreezing(null)} onDone={() => { setFreezing(null); onChanged(); }} />}
    </div>
  );
}

function FreezeDialog({ m, today, onClose, onDone }: { m: Membership; today: string; onClose: () => void; onDone: () => void }) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const max = m.freeze_days_max - m.freeze_days_used;
  const [from, setFrom] = useState(today > m.starts_on ? today : m.starts_on);
  const [days, setDays] = useState(Math.min(7, max));
  const [busy, setBusy] = useState(false);
  const submit = async () => {
    setBusy(true);
    const { error } = await supabase.rpc("freeze_membership", { p_membership: m.id, p_from: from, p_to: addDays(from, days - 1), p_reason: null });
    setBusy(false);
    if (error) return void toast.error(toAppError(error).message);
    toast.success("Абонемент заморожен");
    onDone();
  };
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader><DialogTitle>{t("Заморозка абонемента")}</DialogTitle></DialogHeader>
        <div className="grid gap-4">
          <Field label="С какого дня">
            <Input type="date" value={from} min={today} max={m.ends_on} onChange={(e) => setFrom(e.target.value)} />
          </Field>
          <Field label="Сколько дней" hint={t("Доступно {n} дн. Абонемент продлится на столько же.", { n: max })}>
            <Input type="number" min={1} max={max} value={days} onChange={(e) => setDays(Math.max(1, Math.min(max, Number(e.target.value) || 1)))} />
          </Field>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>{t("Отмена")}</Button>
          <Button onClick={submit} disabled={busy}>{t("Заморозить")}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// ── Расписание и запись ───────────────────────────────────────────
function ScheduleTab({ gymId, tz }: { gymId: string; tz: string }) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [items, setItems] = useState<ClassItem[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const fetchItems = useCallback(async () => {
    const { data, error } = await supabase.rpc("public_schedule", { p_gym: gymId, p_days: 14 });
    if (error) toast.error(toAppError(error).message);
    return (data as ClassItem[]) ?? [];
  }, [supabase, gymId]);
  useEffect(() => { void fetchItems().then(setItems); }, [fetchItems]);

  const book = async (item: ClassItem) => {
    setBusy(item.id);
    const { error } = item.my_booking_id
      ? await supabase.rpc("cancel_booking", { p_booking: item.my_booking_id })
      : await supabase.rpc("book_class", { p_item: item.id, p_client: null });
    setBusy(null);
    if (error) return void toast.error(toAppError(error).message);
    toast.success(item.my_booking_id ? "Запись отменена" : "Вы записаны");
    setItems(await fetchItems());
  };

  if (!items) return <div className="grid gap-3"><Skeleton className="h-20 rounded-3xl" /><Skeleton className="h-20 rounded-3xl" /></div>;
  if (!items.length) return <p className="py-10 text-center text-muted-foreground">{t("В ближайшие две недели занятий нет")}</p>;
  return <ClassList items={items} tz={tz} busy={busy} onAction={book} />;
}

// ── Профиль ───────────────────────────────────────────────────────
function ProfileTab({ client, clients, gym, onSwitch, onSignOut }: {
  client: LinkedClient; clients: LinkedClient[]; gym: Gym | null; onSwitch: (id: string) => void; onSignOut: () => void;
}) {
  const supabase = useMemo(() => createClient(), []);
  const t = useT();
  const [visits, setVisits] = useState<{ id: string; checked_in_at: string }[] | null>(null);
  const [confirm, setConfirm] = useState(false);

  useEffect(() => {
    void supabase.from("visits").select("id,checked_in_at").eq("client_id", client.client_id)
      .order("checked_in_at", { ascending: false }).limit(10).then(({ data }) => setVisits(data ?? []));
  }, [supabase, client.client_id]);

  const remove = async () => {
    const r = await deleteMemberAccount();
    if (!r.ok) return void toast.error(r.error.message);
    toast.success("Аккаунт удалён");
    onSignOut();
  };

  const tz = gym?.timezone ?? "Europe/Moscow";
  const fmt = (ts: string) => new Intl.DateTimeFormat(t.intl, { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23", timeZone: tz }).format(new Date(ts));

  return (
    <div className="grid gap-4">
      <div className="grid gap-1 rounded-3xl bg-card p-5">
        <p className="text-lg font-semibold">{client.full_name}</p>
        {gym && <p className="text-sm text-muted-foreground">{gym.name}{gym.address ? `, ${gym.address}` : ""}</p>}
        {gym?.phone && <a href={`tel:${gym.phone}`} className="text-sm text-tint-text">{formatPhone(gym.phone)}</a>}
      </div>
      {clients.length > 1 && (
        <div className="grid gap-2 rounded-3xl bg-card p-5">
          <p className="text-sm font-semibold">{t("Мои залы")}</p>
          {clients.map((c) => (
            <button key={c.client_id} type="button" onClick={() => onSwitch(c.client_id)}
              className={cn("cursor-pointer rounded-xl px-3 py-2 text-left", c.client_id === client.client_id ? "bg-tint-soft text-tint-text" : "hover:bg-field")}>
              {c.gym_name}
            </button>
          ))}
        </div>
      )}
      <div className="grid gap-2 rounded-3xl bg-card p-5">
        <p className="text-sm font-semibold">{t("Последние посещения")}</p>
        {!visits ? <Skeleton className="h-10" /> : !visits.length ? <p className="text-sm text-muted-foreground">{t("Посещений пока нет")}</p> : (
          <ul className="grid gap-1 text-sm">{visits.map((v) => <li key={v.id} className="tabular">{fmt(v.checked_in_at)}</li>)}</ul>
        )}
      </div>
      <div className="flex items-center justify-between rounded-3xl bg-card p-5">
        <p className="text-sm font-semibold">{t("Язык")}</p>
        <LanguageSwitch />
      </div>
      <Button variant="outline" onClick={onSignOut}>{t("Выйти")}</Button>
      <Button variant="ghost" className="text-destructive" onClick={() => setConfirm(true)}>{t("Удалить аккаунт")}</Button>
      <Dialog open={confirm} onOpenChange={setConfirm}>
        <DialogContent>
          <DialogHeader><DialogTitle>{t("Удалить аккаунт?")}</DialogTitle></DialogHeader>
          <p className="text-sm text-muted-foreground">{t("Ваши данные во всех залах будут обезличены, аккаунт входа будет удалён. Записи об оплатах залы сохранят для бухгалтерии.")}</p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirm(false)}>{t("Отмена")}</Button>
            <Button variant="destructive" onClick={remove}>{t("Удалить")}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
      <p className="text-center text-xs text-muted-foreground">
        <a href="/terms">{t("Условия использования")}</a> · <a href="/privacy">{t("Политика конфиденциальности")}</a>
      </p>
    </div>
  );
}
