"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { Camera, CameraOff, CheckCircle2, LogOut, QrCode, ShoppingCart, Users, XCircle, Keyboard } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Avatar, Alert, EmptyState } from "@/components/ui/misc";
import { ClientSearch } from "@/components/client-search";
import { SellDialog } from "@/components/sell-dialog";
import { createClient } from "@/lib/supabase/client";
import { toAppError } from "@/lib/errors";
import { date, plural, time } from "@/lib/format";
import { looksLikeCoreQr } from "@/lib/qr";
import type { CheckinResult, ClientRow } from "@/lib/types";
import { cn } from "@/lib/utils";

interface InGym {
  visit_id: string;
  client_id: string;
  full_name: string;
  photo_url: string | null;
  checked_in_at: string;
  plan_name: string | null;
  membership_ends_on: string | null;
}

export function ReceptionScreen({ gymId, timezone, today, capacity, readOnly }: {
  gymId: string; timezone: string; today: string; capacity: number; readOnly: boolean;
}) {
  const [supabase] = useState(createClient);
  const [result, setResult] = useState<CheckinResult | null>(null);
  const [inGym, setInGym] = useState<InGym[]>([]);
  const [cameraOn, setCameraOn] = useState(false);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [sellFor, setSellFor] = useState<{ id: string; full_name: string } | null>(null);
  const busy = useRef(false);
  const lastScan = useRef<{ text: string; at: number } | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const dismissTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const loadInGym = useCallback(async () => {
    const { data } = await supabase.from("v_in_gym").select("*").eq("gym_id", gymId).order("checked_in_at", { ascending: false });
    setInGym((data ?? []) as InGym[]);
  }, [supabase, gymId]);

  // «Кто сейчас в зале» + обновление в реальном времени
  useEffect(() => {
    const first = setTimeout(loadInGym, 0);
    const channel = supabase
      .channel(`reception-${gymId}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "visits", filter: `gym_id=eq.${gymId}` }, () => loadInGym())
      .subscribe();
    const t = setInterval(loadInGym, 60_000);
    return () => {
      clearTimeout(first);
      clearInterval(t);
      supabase.removeChannel(channel);
    };
  }, [supabase, gymId, loadInGym]);

  const show = useCallback((r: CheckinResult) => {
    setResult(r);
    beep(r.ok);
    if (dismissTimer.current) clearTimeout(dismissTimer.current);
    if (r.ok) dismissTimer.current = setTimeout(() => setResult(null), 3500);
    if (r.ok) loadInGym();
  }, [loadInGym]);

  const checkQr = useCallback(async (text: string) => {
    const payload = text.trim();
    const now = Date.now();
    if (busy.current) return;
    if (lastScan.current && lastScan.current.text === payload && now - lastScan.current.at < 4000) return;
    lastScan.current = { text: payload, at: now };
    if (!looksLikeCoreQr(payload)) {
      show({ ok: false, code: "QR_INVALID", message: "Это не QR-пропуск core.", client: null, membership: null });
      return;
    }
    busy.current = true;
    try {
      const { data, error } = await supabase.rpc("checkin_qr", { p_gym: gymId, p_payload: payload });
      if (error) {
        const e = toAppError(error);
        show({ ok: false, code: e.code, message: e.message, client: null, membership: null });
      } else show(data as CheckinResult);
    } finally {
      busy.current = false;
    }
  }, [supabase, gymId, show]);

  const checkManual = useCallback(async (c: ClientRow) => {
    const { data, error } = await supabase.rpc("checkin_manual", { p_client: c.id });
    if (error) {
      const e = toAppError(error);
      show({ ok: false, code: e.code, message: e.message, client: { id: c.id, full_name: c.full_name, photo_url: null, phone: c.phone }, membership: null });
    } else show(data as CheckinResult);
  }, [supabase, show]);

  // Камера планшета или веб-камера (FR-4.1)
  useEffect(() => {
    if (!cameraOn || !videoRef.current) return;
    let scanner: { start: () => Promise<void>; stop: () => void; destroy: () => void } | null = null;
    let cancelled = false;
    (async () => {
      const { default: QrScanner } = await import("qr-scanner");
      if (cancelled || !videoRef.current) return;
      const s = new QrScanner(videoRef.current, (res) => checkQr(res.data), {
        preferredCamera: "environment",
        highlightScanRegion: true,
        highlightCodeOutline: true,
        maxScansPerSecond: 8,
        returnDetailedScanResult: true,
      });
      scanner = s;
      try {
        await s.start();
        setCameraError(null);
      } catch {
        setCameraError("Нет доступа к камере. Разрешите доступ в настройках браузера или используйте ручной сканер.");
        setCameraOn(false);
      }
    })();
    return () => {
      cancelled = true;
      scanner?.stop();
      scanner?.destroy();
    };
  }, [cameraOn, checkQr]);

  // Ручной USB/Bluetooth-сканер работает как клавиатура: собираем строку до Enter
  useEffect(() => {
    let buf = "";
    let last = 0;
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;
      const now = Date.now();
      if (now - last > 80) buf = "";
      last = now;
      if (e.key === "Enter") {
        if (buf.startsWith("CORE1:")) checkQr(buf);
        buf = "";
      } else if (e.key.length === 1) {
        buf += e.key;
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [checkQr]);

  async function checkout(visitId: string) {
    const { error } = await supabase.rpc("checkout_visit", { p_visit: visitId });
    if (error) toast.error(toAppError(error).message);
    else loadInGym();
  }

  const load = capacity > 0 ? Math.round((inGym.length / capacity) * 100) : null;

  return (
    <div className="grid gap-6 xl:grid-cols-[1fr_380px]">
      <div className="grid content-start gap-6">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold tracking-tight sm:text-[28px]">Ресепшен</h1>
            <p className="text-sm text-muted-foreground">Сканируйте QR из приложения или найдите клиента вручную</p>
          </div>
          <Button variant={cameraOn ? "outline" : "default"} size="lg" onClick={() => setCameraOn((v) => !v)} disabled={readOnly}>
            {cameraOn ? <><CameraOff /> Выключить камеру</> : <><Camera /> Включить камеру</>}
          </Button>
        </div>

        {readOnly ? <Alert variant="warning">Кабинет в режиме «только чтение» — отметка визитов недоступна.</Alert> : null}
        {cameraError ? <Alert variant="danger">{cameraError}</Alert> : null}

        <Card className="overflow-hidden">
          {cameraOn ? (
            <div className="relative aspect-[4/3] max-h-[56vh] w-full bg-sidebar sm:aspect-video">
              <video ref={videoRef} className="absolute inset-0 size-full object-cover" muted playsInline />
              <span className="absolute left-4 top-4 inline-flex items-center gap-2 rounded-full bg-black/55 px-3 py-1.5 text-xs font-medium text-white backdrop-blur">
                <span className="relative flex size-2"><span className="absolute inline-flex size-full animate-ping rounded-full bg-brand opacity-75" /><span className="relative inline-flex size-2 rounded-full bg-brand" /></span>
                Камера сканирует
              </span>
            </div>
          ) : (
            <div className="grid gap-6 p-6 sm:grid-cols-[auto_1fr] sm:items-center sm:p-8">
              <div className="relative mx-auto grid size-32 place-items-center rounded-3xl bg-sidebar text-brand sm:mx-0">
                <QrCode className="size-14" strokeWidth={1.4} />
                <span aria-hidden className="absolute inset-x-5 top-1/2 h-0.5 -translate-y-1/2 rounded-full bg-brand shadow-[0_0_12px_2px_var(--brand)] animate-[scan_2.4s_ease-in-out_infinite]" />
              </div>
              <div className="grid gap-3 text-center sm:text-left">
                <p className="inline-flex items-center justify-center gap-2 text-sm font-medium text-success sm:justify-start">
                  <span className="size-2 rounded-full bg-success" /> Сканер готов
                </p>
                <p className="text-xl font-semibold tracking-tight">Поднесите QR-пропуск из приложения</p>
                <p className="text-sm text-muted-foreground">
                  Ручной сканер штрихкодов работает сразу. Для камеры планшета или веб-камеры нажмите «Включить камеру».
                </p>
              </div>
            </div>
          )}
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2"><Keyboard className="size-4 text-muted-foreground" /> Отметить вручную</CardTitle>
          </CardHeader>
          <CardContent>
            <ClientSearch gymId={gymId} size="lg" onSelect={checkManual} placeholder="Начните вводить фамилию или телефон" />
          </CardContent>
        </Card>
      </div>

      <Card className="content-start self-start xl:sticky xl:top-8">
        <CardHeader className="flex-row items-center justify-between">
          <CardTitle className="flex items-center gap-2"><Users className="size-4 text-muted-foreground" /> Сейчас в зале</CardTitle>
          <span className="text-sm tabular text-muted-foreground">
            <b className="text-2xl font-bold text-foreground">{inGym.length}</b>
            {capacity ? ` / ${capacity}` : ""}{load !== null ? ` · ${load}%` : ""}
          </span>
        </CardHeader>
        <CardContent className="grid gap-1">
          {inGym.length === 0 ? (
            <EmptyState title="В зале никого" className="py-8">Отмеченные клиенты появятся здесь сразу после скана.</EmptyState>
          ) : inGym.map((v) => (
            <div key={v.visit_id} className="flex items-center gap-3 rounded-xl px-2 py-2 hover:bg-muted/50">
              <Avatar name={v.full_name} src={v.photo_url} className="size-9 text-xs" />
              <Link href={`/clients/${v.client_id}`} className="min-w-0 flex-1">
                <span className="block truncate text-sm font-medium">{v.full_name}</span>
                <span className="block text-xs text-muted-foreground">с {time(v.checked_in_at, timezone)}{v.plan_name ? ` · ${v.plan_name}` : ""}</span>
              </Link>
              <Button variant="ghost" size="icon-sm" onClick={() => checkout(v.visit_id)} aria-label="Отметить выход" title="Отметить выход">
                <LogOut />
              </Button>
            </div>
          ))}
        </CardContent>
      </Card>

      {result ? (
        <ResultOverlay
          result={result}
          onClose={() => setResult(null)}
          onSell={result.client && !readOnly ? () => { setSellFor({ id: result.client!.id, full_name: result.client!.full_name }); setResult(null); } : undefined}
        />
      ) : null}

      {sellFor ? (
        <SellDialog
          open
          onOpenChange={(v) => !v && setSellFor(null)}
          gymId={gymId}
          client={sellFor}
          today={today}
          onDone={() => setSellFor(null)}
        />
      ) : null}
    </div>
  );
}

/** FR-4.2 Результат проверки на весь экран */
function ResultOverlay({ result, onClose, onSell }: { result: CheckinResult; onClose: () => void; onSell?: () => void }) {
  const ok = result.ok;
  const m = result.membership;
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  const canSell = !ok && onSell && ["NO_ACTIVE_MEMBERSHIP", "NO_VISITS_LEFT", "MEMBERSHIP_NOT_STARTED"].includes(result.code);
  return (
    <div
      role="alertdialog"
      aria-live="assertive"
      aria-label={ok ? "Проход разрешён" : "Проход запрещён"}
      onClick={onClose}
      className={cn(
        "fixed inset-0 z-[60] flex flex-col items-center justify-center gap-6 p-6 text-center text-white animate-in fade-in-0 zoom-in-95 duration-150",
        ok ? "bg-[oklch(0.52_0.14_150)]" : "bg-[oklch(0.52_0.2_25)]",
      )}
    >
      {ok ? <CheckCircle2 className="size-20 sm:size-24" strokeWidth={1.5} /> : <XCircle className="size-20 sm:size-24" strokeWidth={1.5} />}
      {result.client ? (
        <div className="flex flex-col items-center gap-3">
          <Avatar name={result.client.full_name} src={result.client.photo_url} className="size-28 bg-white/20 text-3xl text-white ring-4 ring-white/25 dark:bg-white/20 dark:text-white sm:size-36" />
          <p className="text-3xl font-bold tracking-tight sm:text-5xl">{result.client.full_name}</p>
        </div>
      ) : null}
      <p className="text-xl font-semibold sm:text-3xl">{result.repeat ? "Визит уже отмечен" : result.message}</p>
      {ok && m ? (
        <p className="text-lg text-white/85 sm:text-2xl">
          {m.plan_name} · до {date(m.ends_on)}
          {m.visits_left !== null ? ` · осталось ${m.visits_left} ${plural(m.visits_left, "визит", "визита", "визитов")}` : ""}
        </p>
      ) : null}
      <div className="flex flex-wrap justify-center gap-3" onClick={(e) => e.stopPropagation()}>
        {canSell ? (
          <Button size="xl" className="bg-white text-black hover:bg-white/90" onClick={onSell}>
            <ShoppingCart /> Продать абонемент
          </Button>
        ) : null}
        <Button size="xl" variant="outline" className="border-white/40 bg-transparent text-white hover:bg-white/10" onClick={onClose}>
          {ok ? "Готово" : "Закрыть"}
        </Button>
      </div>
    </div>
  );
}

function beep(ok: boolean) {
  try {
    const ctx = new AudioContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.frequency.value = ok ? 880 : 220;
    osc.type = ok ? "sine" : "square";
    gain.gain.value = 0.08;
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + (ok ? 0.12 : 0.35));
    osc.onended = () => ctx.close();
  } catch {
    /* звук не критичен */
  }
}
