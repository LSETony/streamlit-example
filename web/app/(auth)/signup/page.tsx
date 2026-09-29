"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Checkbox, Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createClient } from "@/lib/supabase/client";

export default function SignupPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    const email = String(form.get("email")).trim();
    setPending(true);
    setError(null);
    const { data, error } = await createClient().auth.signUp({
      email,
      password: String(form.get("password")),
      options: { emailRedirectTo: `${window.location.origin}/auth/callback?next=/onboarding` },
    });
    setPending(false);
    if (error) {
      setError(error.message.includes("already registered") ? "Этот email уже зарегистрирован — войдите" : error.message);
      return;
    }
    if (data.session) {
      router.replace("/onboarding");
      router.refresh();
    } else {
      setSent(email);
    }
  }

  if (sent) {
    return (
      <div className="grid gap-3">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">Проверьте почту</h1>
        <p className="text-sm text-muted-foreground">
          Мы отправили письмо на <b className="text-foreground">{sent}</b>. Перейдите по ссылке, чтобы продолжить настройку зала.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="grid gap-5">
      <div className="grid gap-1.5">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">Подключить зал</h1>
        <p className="text-sm text-muted-foreground">14 дней бесплатно. Настройка — около 15 минут.</p>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <Field label="Email владельца">
        <Input name="email" type="email" autoComplete="email" required />
      </Field>
      <Field label="Пароль" hint="Не короче 8 символов">
        <Input name="password" type="password" autoComplete="new-password" required minLength={8} />
      </Field>
      <Checkbox
        required
        name="offer"
        label={<span className="text-muted-foreground">Принимаю условия оферты и поручение на обработку персональных данных клиентов зала</span>}
      />
      <Button type="submit" size="lg" disabled={pending}>{pending ? "Создаём…" : "Создать кабинет"}</Button>
      <p className="text-center text-sm text-muted-foreground">
        Уже есть кабинет? <Link href="/login" className="font-medium text-foreground hover:underline">Войти</Link>
      </p>
    </form>
  );
}
