"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { saveStripe } from "@/app/actions/gym";
import { useT } from "@/lib/i18n/client";

/** Ключи Stripe зала: оплата абонементов по ссылке и в приложении, деньги — на счёт зала в Stripe */
export function StripeForm({ status, webhookUrl, disabled }: { status: { connected: boolean; webhook: boolean }; webhookUrl: string; disabled?: boolean }) {
  const t = useT();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <form className="grid gap-4" action={(f) => start(async () => {
      setError(null);
      const r = await saveStripe(f);
      if (!r.ok) return setError(r.error.message);
      toast.success("Ключи Stripe сохранены");
      router.refresh();
    })}>
      <div className="flex flex-wrap gap-2">
        {status.connected ? <Badge variant="success">Ключ подключён</Badge> : <Badge variant="outline">Не подключено</Badge>}
        {status.connected ? (status.webhook ? <Badge variant="success">Уведомления настроены</Badge> : <Badge variant="warning">Нет секрета уведомлений</Badge>) : null}
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Секретный ключ" hint={status.connected ? "Оставьте пустым, чтобы не менять" : "sk_live_… — Developers → API keys"}>
          <Input name="secret_key" type="password" autoComplete="off" required={!status.connected} />
        </Field>
        <Field label="Секрет подписи уведомлений" hint={status.webhook ? "Оставьте пустым, чтобы не менять" : "whsec_… — появится после создания адреса уведомлений"}>
          <Input name="webhook_secret" type="password" autoComplete="off" />
        </Field>
      </div>
      <Alert>
        {t("В Stripe откройте Developers → Webhooks, добавьте адрес")} <code className="break-all text-xs">{webhookUrl}</code>
        {" "}{t("и события")} checkout.session.completed, checkout.session.expired, checkout.session.async_payment_succeeded, checkout.session.async_payment_failed.
      </Alert>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button type="submit" disabled={pending || disabled}>Сохранить</Button></div>
    </form>
  );
}
