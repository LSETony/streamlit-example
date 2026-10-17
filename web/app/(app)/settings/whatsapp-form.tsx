"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { saveWhatsapp } from "@/app/actions/gym";
import { useT } from "@/lib/i18n/client";

export function WhatsappForm({ status, disabled }: { status: { connected: boolean; phoneId: string | null; template: string | null; lang: string }; disabled?: boolean }) {
  const t = useT();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <form className="grid gap-4" action={(f) => start(async () => {
      setError(null);
      const r = await saveWhatsapp(f);
      if (!r.ok) return setError(r.error.message);
      toast.success("WhatsApp Business подключён");
      router.refresh();
    })}>
      <div>{status.connected ? <Badge variant="success">{t("Подключено · шаблон {name}", { name: status.template ?? "" })}</Badge> : <Badge variant="outline">Не подключено</Badge>}</div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Phone number ID" hint="Из WhatsApp Manager → API Setup">
          <Input name="phone_id" defaultValue={status.phoneId ?? ""} required inputMode="numeric" />
        </Field>
        <Field label="Токен доступа" hint={status.connected ? "Оставьте пустым, чтобы не менять" : "Постоянный токен системного пользователя"}>
          <Input name="token" type="password" autoComplete="off" required={!status.connected} />
        </Field>
        <Field label="Название шаблона" hint="Одобренный шаблон: {{1}} — имя клиента, {{2}} — название зала">
          <Input name="template" defaultValue={status.template ?? ""} required placeholder="winback_reminder" />
        </Field>
        <Field label="Язык шаблона">
          <NativeSelect name="lang" defaultValue={status.lang}>
            <option value="en">English</option>
            <option value="ru">Русский</option>
            <option value="ar">العربية</option>
          </NativeSelect>
        </Field>
      </div>
      <Alert>{t("Сообщения уходят только клиентам с согласием на рассылки, а контакт отмечается в списке «В зоне риска» автоматически.")}</Alert>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button type="submit" disabled={pending || disabled}>Сохранить</Button></div>
    </form>
  );
}
