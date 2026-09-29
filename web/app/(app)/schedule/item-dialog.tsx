"use client";
import Link from "next/link";
import { useCallback, useEffect, useState, useTransition } from "react";
import { toast } from "sonner";
import { Ban, Check, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { ClientSearch } from "@/components/client-search";
import { createClient } from "@/lib/supabase/client";
import { bookClient, cancelBooking, cancelClass, markBooking, updateItem } from "@/app/actions/schedule";
import { dateTime, time } from "@/lib/format";
import type { Item } from "./schedule-view";

interface B { id: string; status: "booked" | "cancelled" | "attended" | "no_show"; channel: "app" | "staff"; client_id: string; clients: { full_name: string } | null }

export function ItemDialog({ item, zones, gymId, timezone, canEdit, readOnly, onClose }: {
  item: Item; zones: { id: string; name: string }[]; gymId: string; timezone: string; canEdit: boolean; readOnly: boolean; onClose: () => void;
}) {
  const [bookings, setBookings] = useState<B[]>([]);
  const [edit, setEdit] = useState(false);
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [past] = useState(() => new Date(item.starts_at).getTime() < Date.now());
  const [version, setVersion] = useState(0);
  const load = useCallback(() => setVersion((v) => v + 1), []);

  useEffect(() => {
    let alive = true;
    createClient().from("bookings").select("id, status, channel, client_id, clients(full_name)")
      .eq("schedule_item_id", item.id).order("created_at")
      .then(({ data }) => { if (alive) setBookings((data ?? []) as unknown as B[]); });
    return () => { alive = false; };
  }, [item.id, version]);

  const active = bookings.filter((b) => b.status !== "cancelled");
  const run = (fn: () => Promise<{ ok: boolean; error?: { message: string } }>, okText?: string) => start(async () => {
    setError(null);
    const r = await fn();
    if (!r.ok) return setError(r.error!.message);
    if (okText) toast.success(okText);
    load();
  });

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent wide>
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">{item.title} {item.cancelled ? <Badge variant="danger">Отменено</Badge> : null}</DialogTitle>
          <DialogDescription>
            {dateTime(item.starts_at, timezone)}–{time(item.ends_at, timezone)}
            {item.trainer_name ? ` · ${item.trainer_name}` : ""}{zones.find((z) => z.id === item.zone_id) ? ` · ${zones.find((z) => z.id === item.zone_id)!.name}` : ""}
            {` · записано ${active.length} из ${item.capacity}`}
          </DialogDescription>
        </DialogHeader>

        {edit ? (
          <EditForm item={item} zones={zones} onDone={() => { setEdit(false); onClose(); }} />
        ) : (
          <>
            {!item.cancelled && !past && !readOnly ? (
              <ClientSearch gymId={gymId} placeholder="Записать клиента: ФИО или телефон" onSelect={(c) => run(() => bookClient(item.id, c.id), `${c.full_name} записан(а)`)} />
            ) : null}
            <div className="grid max-h-80 gap-1 overflow-y-auto">
              {active.length === 0 ? <p className="py-4 text-center text-sm text-muted-foreground">Пока никто не записан</p> : active.map((b) => (
                <div key={b.id} className="flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-muted/50">
                  <Link href={`/clients/${b.client_id}`} className="flex-1 truncate text-sm font-medium hover:underline">{b.clients?.full_name}</Link>
                  {b.channel === "app" ? <Badge variant="outline">приложение</Badge> : null}
                  {b.status === "attended" ? <Badge variant="success">пришёл</Badge> : b.status === "no_show" ? <Badge variant="danger">не пришёл</Badge> : null}
                  {!readOnly ? (
                    <div className="flex gap-0.5">
                      <Button size="icon-sm" variant="ghost" title="Пришёл" aria-label="Пришёл" onClick={() => run(() => markBooking(b.id, b.status === "attended" ? "booked" : "attended"))}><Check /></Button>
                      <Button size="icon-sm" variant="ghost" title="Не пришёл" aria-label="Не пришёл" onClick={() => run(() => markBooking(b.id, b.status === "no_show" ? "booked" : "no_show"))}><Ban /></Button>
                      {b.status === "booked" && !past ? <Button size="icon-sm" variant="ghost" title="Отменить запись" aria-label="Отменить запись" onClick={() => run(() => cancelBooking(b.id), "Запись отменена")}><X /></Button> : null}
                    </div>
                  ) : null}
                </div>
              ))}
            </div>
            {error ? <Alert variant="danger">{error}</Alert> : null}
            {canEdit && !item.cancelled ? (
              <DialogFooter>
                <Button variant="ghost" className="text-destructive sm:mr-auto" disabled={pending || past} onClick={() => {
                  const reason = prompt("Причина отмены (увидят записавшиеся):") ;
                  if (reason === null) return;
                  run(async () => {
                    const r = await cancelClass(item.id, reason || null);
                    if (r.ok) toast.success(`Занятие отменено, уведомлено: ${r.data.notified}`);
                    return r;
                  });
                }}>Отменить занятие</Button>
                <Button variant="outline" onClick={() => setEdit(true)}>Изменить</Button>
              </DialogFooter>
            ) : null}
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}

function EditForm({ item, zones, onDone }: { item: Item; zones: { id: string; name: string }[]; onDone: () => void }) {
  const [pending, start] = useTransition();
  const [error, setError] = useState<string | null>(null);
  return (
    <form className="grid gap-4" action={(f) => start(async () => {
      const r = await updateItem({
        id: item.id, seriesId: item.series_id, applyToSeries: f.get("series") === "on", startsAt: item.starts_at,
        title: String(f.get("title")), trainer: String(f.get("trainer")).trim() || null, capacity: Number(f.get("capacity")), zoneId: String(f.get("zone")) || null,
      });
      if (!r.ok) return setError(r.error.message);
      toast.success("Сохранено");
      onDone();
    })}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Название"><Input name="title" defaultValue={item.title} required /></Field>
        <Field label="Тренер"><Input name="trainer" defaultValue={item.trainer_name ?? ""} /></Field>
        <Field label="Зона">
          <NativeSelect name="zone" defaultValue={item.zone_id ?? ""}>
            <option value="">Без зоны</option>
            {zones.map((z) => <option key={z.id} value={z.id}>{z.name}</option>)}
          </NativeSelect>
        </Field>
        <Field label="Мест"><Input name="capacity" type="number" min={1} defaultValue={item.capacity} required /></Field>
      </div>
      {item.series_id ? <Checkbox name="series" defaultChecked label="Применить ко всем следующим занятиям серии" /> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <DialogFooter><Button type="submit" disabled={pending}>Сохранить</Button></DialogFooter>
    </form>
  );
}
