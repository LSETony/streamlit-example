"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState, useTransition } from "react";
import { toast } from "sonner";
import { Phone, Send, MessageCircle, BellRing, Check, ShieldCheck } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/misc";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, NativeSelect, Textarea } from "@/components/ui/input";
import { RiskBadge } from "@/components/status";
import { markContacted } from "@/app/actions/risk";
import { date, dateTime, phone } from "@/lib/format";
import type { RiskReason, RiskRow } from "@/lib/types";
import { RISK_LABEL } from "@/lib/types";
import { cn } from "@/lib/utils";

const ORDER: RiskReason[] = ["not_renewed", "expiring", "gone", "declining"];
const DEFAULT_TEMPLATES: Record<RiskReason, string> = {
  gone: "{name}, давно вас не видели в {gym}! Ждём на тренировке.",
  expiring: "{name}, ваш абонемент в {gym} заканчивается {date}. Продлите заранее.",
  declining: "{name}, заметили, что вы стали реже приходить в {gym}. Можем подобрать удобное время?",
  not_renewed: "{name}, ваш абонемент в {gym} закончился. Возвращайтесь — поможем с продлением.",
};

function fill(tpl: string, row: RiskRow, gym: string) {
  const first = row.full_name.split(" ").length > 1 ? row.full_name.split(" ")[1] : row.full_name;
  return tpl.replaceAll("{name}", first).replaceAll("{gym}", gym).replaceAll("{date}", date(row.membership_ends_on));
}

export function RiskList({ rows, initialReason, gymName, templates, timezone, stats, readOnly }: {
  rows: RiskRow[]; initialReason: RiskReason | ""; gymName: string; templates?: Record<RiskReason, string>;
  timezone: string; stats: { contacted: number; returned: number }; readOnly: boolean;
}) {
  const [reason, setReason] = useState<RiskReason | "">(initialReason);
  const [hideContacted, setHideContacted] = useState(false);
  const [contactFor, setContactFor] = useState<{ row: RiskRow; channel: Channel } | null>(null);
  const counts = useMemo(() => rows.reduce<Record<string, number>>((a, r) => ({ ...a, [r.reason]: (a[r.reason] ?? 0) + 1 }), {}), [rows]);
  const list = rows.filter((r) => (!reason || r.reason === reason) && (!hideContacted || !r.contacted_at));
  const tpl = { ...DEFAULT_TEMPLATES, ...(templates ?? {}) };

  return (
    <div className="grid gap-4">
      <div className="grid gap-3 sm:grid-cols-[1fr_auto] sm:items-center">
        <div className="flex flex-wrap gap-2">
          <Chip active={!reason} onClick={() => setReason("")}>Все · {rows.length}</Chip>
          {ORDER.map((r) => <Chip key={r} active={reason === r} onClick={() => setReason(r)}>{RISK_LABEL[r]} · {counts[r] ?? 0}</Chip>)}
          <Chip active={hideContacted} onClick={() => setHideContacted((v) => !v)}>Без контакта</Chip>
        </div>
        <Card className="flex items-center gap-3 px-4 py-2.5">
          <ShieldCheck className="size-5 text-success" />
          <div className="text-sm">
            <b className="tabular">{stats.returned}</b> из <b className="tabular">{stats.contacted}</b> вернулись после контакта
            <span className="block text-xs text-muted-foreground">за 30 дней: пришли или продлили</span>
          </div>
        </Card>
      </div>

      {list.length === 0 ? (
        <EmptyState icon={<ShieldCheck />} title={rows.length ? "По фильтру никого" : "Никого в зоне риска"}>
          {rows.length ? "Смените фильтр." : "Все клиенты ходят и продлевают абонементы вовремя."}
        </EmptyState>
      ) : (
        <Card className="divide-y divide-border">
          {list.map((r) => {
            const digits = (r.phone ?? "").replace(/\D/g, "");
            const text = encodeURIComponent(fill(tpl[r.reason], r, gymName));
            return (
              <div key={r.client_id} className="grid gap-3 p-4 md:grid-cols-[1fr_auto] md:items-center">
                <div className="grid gap-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <Link href={`/clients/${r.client_id}`} className="font-semibold hover:underline">{r.full_name}</Link>
                    <RiskBadge reason={r.reason} />
                    {r.reasons.filter((x) => x !== r.reason).map((x) => <Badge key={x} variant="outline">{RISK_LABEL[x]}</Badge>)}
                    {r.contacted_at ? <Badge variant="success"><Check className="size-3" /> связались {dateTime(r.contacted_at, timezone).slice(0, 5)}</Badge> : null}
                  </div>
                  <p className="text-sm">{r.reason_text}</p>
                  <p className="text-xs text-muted-foreground tabular">
                    {phone(r.phone)} · последний визит: {r.last_visit_at ? dateTime(r.last_visit_at, timezone) : "не было"}
                  </p>
                </div>
                <div className="flex flex-wrap gap-1.5">
                  <Button size="sm" variant="outline" asChild>
                    <a href={`tel:${r.phone}`} onClick={() => setContactFor({ row: r, channel: "call" })}><Phone /> Позвонить</a>
                  </Button>
                  <Button size="sm" variant="outline" asChild>
                    <a href={`https://wa.me/${digits}?text=${text}`} target="_blank" rel="noreferrer" onClick={() => setContactFor({ row: r, channel: "whatsapp" })}><MessageCircle /> WhatsApp</a>
                  </Button>
                  <Button size="sm" variant="outline" asChild>
                    <a href={`https://t.me/+${digits}`} target="_blank" rel="noreferrer" onClick={() => { navigator.clipboard?.writeText(decodeURIComponent(text)); toast.info("Текст сообщения скопирован"); setContactFor({ row: r, channel: "telegram" }); }}><Send /> Telegram</a>
                  </Button>
                  {r.in_app ? (
                    <Button size="sm" variant="outline" disabled={!r.marketing_ok || readOnly} title={r.marketing_ok ? "" : "Нет согласия на рассылки"} onClick={() => setContactFor({ row: r, channel: "push" })}>
                      <BellRing /> Push
                    </Button>
                  ) : null}
                  <Button size="sm" onClick={() => setContactFor({ row: r, channel: "other" })} disabled={readOnly}><Check /> Связались</Button>
                </div>
              </div>
            );
          })}
        </Card>
      )}

      {contactFor ? (
        <ContactDialog row={contactFor.row} channel={contactFor.channel} text={fill(tpl[contactFor.row.reason], contactFor.row, gymName)} onClose={() => setContactFor(null)} />
      ) : null}
    </div>
  );
}

type Channel = "call" | "telegram" | "whatsapp" | "push" | "other";
const CHANNEL_LABEL: Record<Channel, string> = { call: "Звонок", telegram: "Telegram", whatsapp: "WhatsApp", push: "Push в приложение", other: "Другое" };

/** FR-8.2 Отметка «связались» (для push — отправка сообщения) */
function ContactDialog({ row, channel: initial, text, onClose }: { row: RiskRow; channel: Channel; text: string; onClose: () => void }) {
  const router = useRouter();
  const [channel, setChannel] = useState<Channel>(initial === "other" ? "call" : initial);
  const [note, setNote] = useState("");
  const [pushText, setPushText] = useState(text);
  const [pending, start] = useTransition();
  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{channel === "push" ? "Отправить push" : "Отметить контакт"}</DialogTitle>
          <DialogDescription>{row.full_name} · {RISK_LABEL[row.reason]}</DialogDescription>
        </DialogHeader>
        <Field label="Канал">
          <NativeSelect value={channel} onChange={(e) => setChannel(e.target.value as Channel)}>
            {(Object.keys(CHANNEL_LABEL) as Channel[]).filter((c) => c !== "push" || (row.in_app && row.marketing_ok)).map((c) => <option key={c} value={c}>{CHANNEL_LABEL[c]}</option>)}
          </NativeSelect>
        </Field>
        {channel === "push" ? (
          <Field label="Текст уведомления"><Textarea value={pushText} onChange={(e) => setPushText(e.target.value)} rows={3} maxLength={180} /></Field>
        ) : (
          <Field label="Итог разговора (необязательно)"><Textarea value={note} onChange={(e) => setNote(e.target.value)} rows={3} placeholder="Обещал прийти в четверг" /></Field>
        )}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Не сейчас</Button>
          <Button disabled={pending} onClick={() => start(async () => {
            const r = await markContacted({ clientId: row.client_id, reason: row.reason, channel, note, pushText: channel === "push" ? pushText : undefined });
            if (!r.ok) return void toast.error(r.error.message);
            toast.success(channel === "push" ? "Push поставлен в очередь" : "Контакт отмечен");
            onClose();
            router.refresh();
          })}>{channel === "push" ? "Отправить" : "Сохранить"}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Chip({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} aria-pressed={active}
      className={cn("h-9 cursor-pointer rounded-full px-4 text-sm font-medium transition-colors", active ? "bg-foreground text-background" : "bg-field hover:bg-field-hover")}>
      {children}
    </button>
  );
}
