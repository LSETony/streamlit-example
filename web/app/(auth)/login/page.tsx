import type { Metadata } from "next";
import { LoginForm } from "./login-form";
import { getT } from "@/lib/i18n/server";

export async function generateMetadata(): Promise<Metadata> {
  return { title: (await getT())("Вход") };
}

export default async function LoginPage({ searchParams }: PageProps<"/login">) {
  const { next, error } = await searchParams;
  return <LoginForm next={typeof next === "string" ? next : "/"} error={typeof error === "string" ? error : null} />;
}
