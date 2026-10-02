"use client";
import { Button } from "@/components/ui/button";
import { Alert } from "@/components/ui/misc";
import { useT } from "@/lib/i18n/client";

export default function AppError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  const t = useT();
  return (
    <div className="grid max-w-lg gap-4">
      <Alert variant="danger">{t("Не удалось загрузить раздел. Проверьте интернет и попробуйте ещё раз.")}{error.digest ? ` ${t("Код:")} ${error.digest}` : ""}</Alert>
      <div><Button onClick={reset}>Повторить</Button></div>
    </div>
  );
}
