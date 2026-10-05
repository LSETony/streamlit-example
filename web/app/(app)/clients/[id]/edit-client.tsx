"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { anonymizeClient, updateClientAction } from "@/app/actions/clients";
import type { Client } from "@/lib/types";
import { SOURCES } from "../new-client";
import { useRegion } from "@/lib/region-context";
import { DatePicker } from "@/components/ui/date-picker";
import { useT } from "@/lib/i18n/client";

export function EditClientDialog({ client, onClose }: { client: Client; onClose: () => void }) {
  const { region } = useRegion();
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent wide>
        <DialogHeader><DialogTitle>Данные клиента</DialogTitle></DialogHeader>
        <form className="grid gap-4" action={(form) => start(async () => {
          const r = await updateClientAction(client.id, form);
          if (!r.ok) return setError(r.error.message);
          toast.success("Сохранено");
          onClose();
        })}>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="ФИО"><Input name="full_name" defaultValue={client.full_name} required /></Field>
            <Field label="Телефон"><Input name="phone" type="tel" defaultValue={client.phone ?? ""} required /></Field>
            <Field label="Email"><Input name="email" type="email" defaultValue={client.email ?? ""} /></Field>
            <Field label="Дата рождения"><DatePicker name="birth_date" defaultValue={client.birth_date ?? ""} max={new Date().toISOString().slice(0, 10)} placeholder="Не указана" clearable aria-label="Дата рождения" /></Field>
            <Field label="Пол">
              <NativeSelect name="gender" defaultValue={client.gender ?? ""}>
                <option value="">Не указан</option><option value="female">Женский</option><option value="male">Мужской</option>
              </NativeSelect>
            </Field>
            <Field label="Источник">
              <NativeSelect name="source" defaultValue={client.source ?? ""}>
                <option value="">Не указан</option>
                {Array.from(new Set([...SOURCES[region], ...(client.source ? [client.source] : [])])).map((s) => <option key={s} value={s}>{s}</option>)}
              </NativeSelect>
            </Field>
          </div>
          <Field label="Теги" hint="Через запятую: vip, утро, пилатес"><Input name="tags" defaultValue={client.tags.join(", ")} /></Field>
          <input type="hidden" name="note" value={client.note ?? ""} />
          <Checkbox name="consent_marketing" defaultChecked={!!client.consent_marketing_at} label="Согласен получать рассылки и напоминания" />
          {error ? <Alert variant="danger">{error}</Alert> : null}
          <DialogFooter>
            <Button type="button" variant="outline" onClick={onClose}>Отмена</Button>
            <Button type="submit" disabled={pending}>{pending ? "Сохраняем…" : "Сохранить"}</Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/** FR-2.6 Удаление клиента по его запросу: обезличивание с сохранением оплат */
export function DeleteClientDialog({ client, onClose }: { client: Client; onClose: () => void }) {
  const t = useT();
  const router = useRouter();
  const [confirmText, setConfirmText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <Dialog open onOpenChange={(v) => !v && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Удалить данные клиента?</DialogTitle>
          <DialogDescription>
            {t("ФИО, телефон, email и заметки будут обезличены без возможности восстановления. Оплаты сохранятся для бухгалтерии, будущие записи на занятия будут отменены.")}
          </DialogDescription>
        </DialogHeader>
        <Field label={t("Для подтверждения введите «{word}»", { word: t("удалить") })}><Input value={confirmText} onChange={(e) => setConfirmText(e.target.value)} /></Field>
        {error ? <Alert variant="danger">{error}</Alert> : null}
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>Отмена</Button>
          <Button variant="destructive" disabled={pending || confirmText.trim().toLowerCase() !== t("удалить")} onClick={() => start(async () => {
            const r = await anonymizeClient(client.id);
            if (!r.ok) return setError(r.error.message);
            toast.success("Данные клиента обезличены");
            router.replace("/clients");
          })}>Удалить данные</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
