"use client";
import { Button } from "@/components/ui/button";
import { Alert } from "@/components/ui/misc";

export default function AppError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="grid max-w-lg gap-4">
      <Alert variant="danger">Не удалось загрузить раздел. Проверьте интернет и попробуйте ещё раз.{error.digest ? ` Код: ${error.digest}` : ""}</Alert>
      <div><Button onClick={reset}>Повторить</Button></div>
    </div>
  );
}
