"use client";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, Input, NativeSelect, Textarea } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createSeries } from "@/app/actions/schedule";
import { addDays } from "@/lib/format";
import { cn } from "@/lib/utils";

const WD = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

/** FR-5.2 Разовое или повторяющееся занятие */
export function CreateItemDialog({ gymZones, initialDate, initialTime, onClose }: {
  gymZones: { id: string; name: string; capacity: number }[]; initialDate: string; initialTime: string; onClose: () => void;
}) {
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
      toast.success(r.data.created > 1 ? `Создано занятий: ${r.data.created}` : "Занятие создано");
      onClose();
    });
  }

  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent wide>
        <DialogHeader><DialogTitle>Новое занятие</DialogTitle></DialogHeader>
        <form action={submit} className="grid gap-4">
          <div className="flex rounded-lg border border-border p-0.5">
            {([["class", "Групповое"], ["personal", "Персональная"], ["zone_slot", "Слот зоны"]] as const).map(([k, l]) => (
              <button key={k} type="button" onClick={() => setKind(k)} className={cn("flex-1 cursor-pointer rounded-md py-1.5 text-sm", kind === k ? "bg-foreground text-background" : "text-muted-foreground")}>{l}</button>
            ))}
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Название"><Input name="title" required placeholder={kind === "zone_slot" ? "Сауна" : kind === "personal" ? "Персональная тренировка" : "Йога"} /></Field>
            <Field label="Тренер"><Input name="trainer" placeholder="Имя тренера" /></Field>
            <Field label="Дата"><Input name="date" type="date" defaultValue={initialDate} required /></Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Начало"><Input name="time" type="time" defaultValue={initialTime} required step={300} /></Field>
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
          <label className="flex items-center gap-2 text-sm font-medium">
            <input type="checkbox" checked={repeat} onChange={(e) => setRepeat(e.target.checked)} className="size-4" /> Повторять каждую неделю
          </label>
          {repeat ? (
            <div className="grid gap-3 rounded-xl bg-muted/50 p-3 sm:grid-cols-[1fr_auto] sm:items-end">
              <div className="flex flex-wrap gap-1.5">
                {WD.map((w, i) => (
                  <button key={w} type="button" onClick={() => setWeekdays((s) => s.includes(i + 1) ? s.filter((x) => x !== i + 1) : [...s, i + 1])}
                    className={cn("size-10 cursor-pointer rounded-lg border text-sm", weekdays.includes(i + 1) ? "border-foreground bg-foreground text-background" : "border-border bg-card")}>{w}</button>
                ))}
              </div>
              <Field label="До"><Input name="until" type="date" defaultValue={addDays(initialDate, 83)} /></Field>
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
