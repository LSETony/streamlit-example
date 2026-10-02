"use client";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createClient } from "@/lib/supabase/client";
import { useT } from "@/lib/i18n/client";

// Новый пароль после ссылки из письма (восстановление или приглашение сотрудника)
export default function ResetPasswordPage() {
  const t = useT();
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    const password = String(form.get("password"));
    if (password !== String(form.get("confirm"))) {
      setError("Пароли не совпадают");
      return;
    }
    setPending(true);
    const { error } = await createClient().auth.updateUser({ password });
    setPending(false);
    if (error) {
      setError(error.message.includes("session") ? "Ссылка устарела — запросите новую" : error.message);
      return;
    }
    router.replace("/");
    router.refresh();
  }

  return (
    <form onSubmit={onSubmit} className="grid gap-5">
      <div className="grid gap-1.5">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">{t("Задайте пароль")}</h1>
        <p className="text-sm text-muted-foreground">{t("Не короче 8 символов")}</p>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <Field label="Новый пароль">
        <Input name="password" type="password" autoComplete="new-password" required minLength={8} autoFocus />
      </Field>
      <Field label="Ещё раз">
        <Input name="confirm" type="password" autoComplete="new-password" required minLength={8} />
      </Field>
      <Button type="submit" size="lg" disabled={pending}>{pending ? "Сохраняем…" : "Сохранить и войти"}</Button>
    </form>
  );
}
