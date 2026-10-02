"use client";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, Input, NativeSelect, Textarea, TimeSelect } from "@/components/ui/input";
import { SwitchRow } from "@/components/ui/switch";
import { Alert } from "@/components/ui/misc";
import { Segmented, segmentClass } from "@/components/ui/tabs";
import { createSeries } from "@/app/actions/schedule";
import { addDays } from "@/lib/format";
import { cn } from "@/lib/utils";
import { DatePicker } from "@/components/ui/date-picker";
import { useT } from "@/lib/i18n/client";

const WD = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

/** FR-5.2 Разовое или повторяющееся занятие */
export function CreateItemDialog({ gymZones, initialDate, initialTime, onClose }: {
  gymZones: { id: string; name: string; capacity: number }[]; initialDate: string; initialTime: string; onClose: () => void;
}) {
  const t = useT();
  const [kind, setKind] = useState<"class" | "personal" | "zone_slot">("class");
  const [repeat, setRepeat] = useState(false);
  const initialDow = (new Date(initialDate + "T00:00:00Z").getUTCDay() + 6) % 7 + 1;
  const [weekdays, setWeekdays] = useState<number[]>([initialDow]);
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();

  function submit(form: FormData) {
    setError(null);
    start(async () => {
      const r = await createSeries({
        title: String(form.get("title")),
        kind,
        date: String(form.get("date")),
        time: String(form.get("time")),
        durationMin: Number(form.get("duration")),
        capacity: Number(form.get("capacity")),
        zoneId: String(form.get("zone")) || null,
        trainer: String(form.get("trainer")).trim() || null,
        weekdays: repeat ? weekdays : [],
        until: repeat ? String(form.get("until")) || null : null,
        description: String(form.get("description")).trim() || null,
      });
      if (!r.ok) return setError(r.error.message);
      toast.success(r.data.created > 1 ? "Создано занятий: {n}" : "Занятие создано", { n: r.data.created });
      onClose();
    });
  }

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent wide>
        <DialogHeader><DialogTitle>Новое занятие</DialogTitle></DialogHeader>
        <form action={submit} className="grid gap-4">
          <Segmented className="flex w-full">
            {([["class", "Групповое"], ["personal", "Персональная"], ["zone_slot", "Слот зоны"]] as const).map(([k, l]) => (
              <button key={k} type="button" onClick={() => setKind(k)} aria-pressed={kind === k} className={cn(segmentClass, "flex-1 px-2")}>{t(l)}</button>
            ))}
          </Segmented>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Название"><Input name="title" required placeholder={kind === "zone_slot" ? "Сауна" : kind === "personal" ? "Персональная тренировка" : "Йога"} /></Field>
            <Field label="Тренер"><Input name="trainer" placeholder="Имя тренера" /></Field>
            <Field label="Дата"><DatePicker name="date" defaultValue={initialDate} required aria-label="Дата" /></Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Начало"><TimeSelect name="time" defaultValue={initialTime} step={15} className="w-full" aria-label="Начало" /></Field>
              <Field label="Минут"><Input name="duration" type="number" min={5} max={600} defaultValue={kind === "personal" ? 60 : 55} required /></Field>
            </div>
            <Field label="Зона">
              <NativeSelect name="zone" defaultValue="">
                <option value="">Без зоны</option>
                {gymZones.map((z) => <option key={z.id} value={z.id}>{z.name}</option>)}
              </NativeSelect>
            </Field>
            <Field label="Мест"><Input name="capacity" type="number" min={1} max={500} defaultValue={kind === "personal" ? 1 : 12} required /></Field>
          </div>
          <Field label="Описание (необязательно)"><Textarea name="description" rows={2} /></Field>
          <SwitchRow title="Повторять каждую неделю" checked={repeat} onCheckedChange={setRepeat} />
          {repeat ? (
            <div className="grid gap-3 rounded-xl bg-muted/50 p-3 sm:grid-cols-[1fr_auto] sm:items-end">
              <div className="flex flex-wrap gap-1.5">
                {WD.map((w, i) => (
                  <button key={w} type="button" onClick={() => setWeekdays((s) => s.includes(i + 1) ? s.filter((x) => x !== i + 1) : [...s, i + 1])}
                    className={cn("size-10 cursor-pointer rounded-full text-sm", weekdays.includes(i + 1) ? "bg-tint text-white" : "bg-field hover:bg-field-hover")}>{t(w)}</button>
                ))}
              </div>
              <Field label="До"><DatePicker name="until" defaultValue={addDays(initialDate, 83)} min={initialDate} aria-label="Повторять до" /></Field>
            </div>
          ) : null}
          {error ? <Alert variant="danger">{error}</Alert> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>Отмена</Button>
            <Button type="submit" disabled={pending || (repeat && weekdays.length === 0)}>{pending ? "Создаём…" : "Создать"}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
