import Link from "next/link";
import { Button } from "@/components/ui/button";
import { getT } from "@/lib/i18n/server";

export default async function NotFound() {
  const t = await getT();
  return (
    <div className="grid min-h-[60dvh] place-items-center px-6 text-center">
      <div className="grid gap-3">
        <p className="text-6xl font-bold tracking-tight">404</p>
        <p className="text-muted-foreground">{t("Такой страницы нет или у вас нет к ней доступа")}</p>
        <div><Button asChild><Link href="/">На главную</Link></Button></div>
      </div>
    </div>
  );
}
