"use client";
import Link from "next/link";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createClient } from "@/lib/supabase/client";
import { useT } from "@/lib/i18n/client";

export default function ForgotPasswordPage() {
  const t = useT();
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const email = String(new FormData(e.currentTarget).get("email")).trim();
    setPending(true);
    const { error } = await createClient().auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
    });
    setPending(false);
    if (error) setError(error.message);
    else setSent(true);
  }

  return (
    <form onSubmit={onSubmit} className="grid gap-5">
      <div className="grid gap-1.5">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">{t("Восстановление пароля")}</h1>
        <p className="text-sm text-muted-foreground">{t("Пришлём ссылку для нового пароля на email")}</p>
      </div>
      {sent ? <Alert variant="success">Если такой email зарегистрирован, письмо уже в пути.</Alert> : null}
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <Field label="Email">
        <Input name="email" type="email" autoComplete="email" required />
      </Field>
      <Button type="submit" size="lg" disabled={pending}>{pending ? "Отправляем…" : "Отправить ссылку"}</Button>
      <Link href="/login" className="text-center text-sm text-muted-foreground hover:text-foreground">{t("Вернуться ко входу")}</Link>
    </form>
  );
}
