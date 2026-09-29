"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Alert } from "@/components/ui/misc";
import { createClient } from "@/lib/supabase/client";

export function LoginForm({ next, error: initialError }: { next: string; error: string | null }) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(initialError ? "Ссылка устарела или уже использована. Войдите снова." : null);
  const [pending, setPending] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    setPending(true);
    setError(null);
    const { error } = await createClient().auth.signInWithPassword({
      email: String(form.get("email")).trim(),
      password: String(form.get("password")),
    });
    if (error) {
      setPending(false);
      setError(error.message.includes("Invalid login") ? "Неверный email или пароль" : error.message);
      return;
    }
    router.replace(next.startsWith("/") ? next : "/");
    router.refresh();
  }

  return (
    <form onSubmit={onSubmit} className="grid gap-5">
      <div className="grid gap-1.5">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">Вход в кабинет зала</h1>
        <p className="text-sm text-muted-foreground">Для владельца, администраторов и ресепшена</p>
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      <Field label="Email">
        <Input name="email" type="email" autoComplete="email" required autoFocus />
      </Field>
      <Field label="Пароль">
        <Input name="password" type="password" autoComplete="current-password" required minLength={8} />
      </Field>
      <Button type="submit" size="lg" disabled={pending}>{pending ? "Входим…" : "Войти"}</Button>
      <div className="flex justify-between text-sm">
        <Link href="/forgot-password" className="text-muted-foreground hover:text-foreground">Забыли пароль?</Link>
        <Link href="/signup" className="font-medium hover:underline">Подключить зал</Link>
      </div>
    </form>
  );
}
