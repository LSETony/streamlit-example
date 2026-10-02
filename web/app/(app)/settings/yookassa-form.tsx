"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Field, Input, NativeSelect } from "@/components/ui/input";
import { SwitchRow } from "@/components/ui/switch";
import { Alert } from "@/components/ui/misc";
import { saveYookassa } from "@/app/actions/gym";
import { useT } from "@/lib/i18n/client";

export function YookassaForm({ status, disabled }: { status: { connected: boolean; shopId: string | null; sendReceipt: boolean; vatCode: number }; disabled?: boolean }) {
  const t = useT();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <form className="grid gap-4" action={(f) => start(async () => {
      setError(null);
      const r = await saveYookassa(f);
      if (!r.ok) return setError(r.error.message);
      toast.success("Ключи ЮKassa сохранены");
      router.refresh();
    })}>
      <div>{status.connected ? <Badge variant="success">{t("Подключено · магазин {shop}", { shop: status.shopId ?? "" })}</Badge> : <Badge variant="outline">Не подключено</Badge>}</div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="shopId"><Input name="shop_id" defaultValue={status.shopId ?? ""} required inputMode="numeric" /></Field>
        <Field label="Секретный ключ" hint={status.connected ? "Оставьте пустым, чтобы не менять" : "live_… из личного кабинета ЮKassa"}>
          <Input name="secret_key" type="password" autoComplete="off" required={!status.connected} />
        </Field>
        <Field label="Ставка НДС в чеке">
          <NativeSelect name="vat_code" defaultValue={String(status.vatCode)}>
            <option value="1">Без НДС</option><option value="2">НДС 0%</option><option value="3">НДС 10%</option><option value="4">НДС 20%</option>
            <option value="7">НДС 5%</option><option value="8">НДС 7%</option>
          </NativeSelect>
        </Field>
      </div>
      <SwitchRow name="send_receipt" defaultChecked={status.sendReceipt} title="Чеки по 54-ФЗ" description="ЮKassa отправит чек клиенту на телефон или email" />
      <Alert>
        {t("В личном кабинете ЮKassa укажите адрес для уведомлений:")} <code className="break-all text-xs">{`https://<${t("адрес API")}>/functions/v1/payments/webhook`}</code>,
        {" "}{t("события")} payment.succeeded, payment.canceled, refund.succeeded.
      </Alert>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <div><Button type="submit" disabled={pending || disabled}>Сохранить</Button></div>
    </form>
  );
}
