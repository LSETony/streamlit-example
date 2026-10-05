"use client";
import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";
import { downloadXlsx } from "@/lib/excel";
import { dateTime } from "@/lib/format";
import { METHOD_LABEL } from "@/lib/types";
import type { PaymentListRow } from "./page";
import { useT } from "@/lib/i18n/client";
import { paymentDescription } from "@/lib/i18n/core";
import { useRegion } from "@/lib/region-context";

const STATUS = { succeeded: "Оплачено", pending: "Ожидает", refunded: "Возвращено", failed: "Не прошла" } as const;

/** FR-6.4 Выгрузка журнала оплат в Excel */
export function ExportPayments({ rows, timezone, from, to }: { rows: PaymentListRow[]; timezone: string; from: string; to: string }) {
  const t = useT();
  const { symbol } = useRegion();
  return (
    <Button variant="outline" disabled={!rows.length} onClick={() => downloadXlsx(
      `${t("оплаты")}-${from}-${to}.xlsx`,
      [t("Дата и время"), t("Клиент"), t("Сумма, {cur}", { cur: symbol }), ...["Способ", "Статус", "Тип", "Назначение", "Принял"].map((h) => t(h))],
      rows.map((p) => [
        dateTime(p.paid_at ?? p.created_at, timezone), p.clients?.full_name ?? "", (p.refund_of_id ? -p.amount : p.amount) / 100,
        t(METHOD_LABEL[p.method]), t(STATUS[p.status]), p.refund_of_id ? t("Возврат") : t("Оплата"), paymentDescription(t, p.description), p.staff?.full_name ?? "",
      ]),
      [18, 28, 12, 12, 12, 10, 30, 20],
    )}><Download /> Excel</Button>
  );
}
