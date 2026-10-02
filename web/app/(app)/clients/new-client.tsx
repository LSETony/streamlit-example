"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import Link from "next/link";
import { UserPlus } from "lucide-react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Checkbox, Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createClientAction, findByPhone, type DuplicateClient } from "@/app/actions/clients";
import { normalizePhone } from "@/lib/phone";
import { useT } from "@/lib/i18n/client";

export const SOURCES = ["Instagram", "ВКонтакте", "Яндекс Карты", "2ГИС", "Сайт", "Рекомендация", "Вывеска", "Другое"];

/** FR-2.2 Создание клиента за 30 секунд */
export function NewClientButton({ disabled, autoOpen, className }: { disabled?: boolean; autoOpen?: boolean; className?: string }) {
  const t = useT();
  const router = useRouter();
  const [open, setOpenState] = useState(!!autoOpen && !disabled);
  // открыто по ссылке /clients?new=1 — после закрытия убираем параметр из адреса
  const setOpen = (v: boolean) => {
    setOpenState(v);
    if (!v && autoOpen) router.replace("/clients");
  };
  const [error, setError] = useState<string | null>(null);
  const [dup, setDup] = useState<DuplicateClient | null>(null);
  const [pending, start] = useTransition();

  async function checkPhone(value: string) {
    setDup(normalizePhone(value) ? await findByPhone(value) : null);
  }

  function submit(form: FormData) {
    setError(null);
    start(async () => {
      const res = await createClientAction(form);
      if (!res.ok) return setError(res.error.message);
      toast.success("Клиент добавлен");
      setOpenState(false);
      router.push(`/clients/${res.data.id}?sell=1`);
    });
  }

  return (
    <>
      <Button className={className} onClick={() => { setOpen(true); setDup(null); setError(null); }} disabled={disabled}><UserPlus /> Новый клиент</Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Новый клиент</DialogTitle>
            <DialogDescription>Обязательны ФИО, телефон и согласие на обработку данных</DialogDescription>
          </DialogHeader>
          <form action={submit} className="grid gap-4">
            <Field label="ФИО">
              <Input name="full_name" required autoFocus autoComplete="off" placeholder="Иванова Мария" />
            </Field>
            <Field
              label="Телефон"
              error={dup ? undefined : null}
              hint={dup ? <span className="text-warning-foreground">{t("Уже есть клиент с этим телефоном:")} <Link className="font-medium underline" href={`/clients/${dup.id}`} onClick={() => setOpenState(false)}>{dup.full_name}</Link></span> : undefined}
            >
              <Input name="phone" type="tel" inputMode="tel" required placeholder="+7 900 000-00-00" onBlur={(e) => checkPhone(e.target.value)} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Источник">
                <NativeSelect name="source" defaultValue="">
                  <option value="">Не указан</option>
                  {SOURCES.map((s) => <option key={s} value={s}>{s}</option>)}
                </NativeSelect>
              </Field>
              <Field label="Email (необязательно)">
                <Input name="email" type="email" />
              </Field>
            </div>
            <div className="grid gap-2 rounded-xl bg-muted/50 p-3">
              <Checkbox name="consent_pd" required label="Клиент дал согласие на обработку персональных данных" />
              <Checkbox name="consent_marketing" label="Согласен получать рассылки и напоминания" />
            </div>
            {error ? <Alert variant="danger">{error}</Alert> : null}
            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setOpen(false)}>Отмена</Button>
              <Button type="submit" disabled={pending || !!dup}>{pending ? "Сохраняем…" : "Добавить и продать абонемент"}</Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </>
  );
}
