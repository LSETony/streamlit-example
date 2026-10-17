"use client";
import { Copy, ExternalLink } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useT } from "@/lib/i18n/client";
import { toast } from "@/lib/toast";

/** Ссылки для сайта и соцсетей зала: виджет расписания (iframe) и приложение клиента */
export function SiteLinks({ origin, gymId }: { origin: string; gymId: string }) {
  const t = useT();
  const widget = `${origin}/w/${gymId}`;
  const app = `${origin}/m?gym=${gymId}`;
  const snippet = `<iframe src="${widget}" style="width:100%;min-height:720px;border:0" loading="lazy" title="Schedule"></iframe>`;
  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      toast.success("Скопировано");
    } catch {
      toast.error("Не удалось скопировать");
    }
  };
  const row = (label: string, hint: string, value: string, open?: string) => (
    <div className="grid gap-2">
      <p className="text-sm font-semibold">{t(label)}</p>
      <p className="text-sm text-muted-foreground">{t(hint)}</p>
      <code className="block overflow-x-auto whitespace-pre rounded-xl bg-field px-4 py-3 text-xs">{value}</code>
      <div className="flex gap-2">
        <Button size="sm" variant="secondary" onClick={() => copy(value)}><Copy /> {t("Скопировать")}</Button>
        {open && <Button size="sm" variant="ghost" asChild><a href={open} target="_blank" rel="noreferrer"><ExternalLink /> {t("Открыть")}</a></Button>}
      </div>
    </div>
  );
  return (
    <div className="grid gap-6">
      {row("Виджет расписания для сайта", "Вставьте код на страницу сайта: посетители увидят расписание, свободные места и цены и смогут записаться.", snippet, widget)}
      {row("Приложение для клиентов", "Отправьте ссылку клиентам или разместите в соцсетях: вход по номеру телефона, QR-пропуск, абонементы и запись. Устанавливается на экран «Домой».", app, app)}
    </div>
  );
}
