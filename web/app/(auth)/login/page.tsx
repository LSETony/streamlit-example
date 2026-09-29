import type { Metadata } from "next";
import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Вход" };

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const { next, error } = await searchParams;
  return <LoginForm next={typeof next === "string" ? next : "/"} error={typeof error === "string" ? error : null} />;
}
