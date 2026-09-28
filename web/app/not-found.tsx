import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function NotFound() {
  return (
    <div className="grid min-h-[60dvh] place-items-center px-6 text-center">
      <div className="grid gap-3">
        <p className="text-6xl font-bold tracking-tight">404</p>
        <p className="text-muted-foreground">Такой страницы нет или у вас нет к ней доступа</p>
        <div><Button asChild><Link href="/">На главную</Link></Button></div>
      </div>
    </div>
  );
}
