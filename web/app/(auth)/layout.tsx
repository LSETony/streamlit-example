import { Logo } from "@/components/logo";

export default function AuthLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="grid min-h-dvh lg:grid-cols-[1fr_1.1fr]">
      <div className="flex flex-col px-6 py-8 sm:px-12">
        <Logo className="h-9 self-start" />
        <div className="flex flex-1 items-center justify-center py-10">
          <div className="w-full max-w-sm">{children}</div>
        </div>
        <p className="text-xs text-muted-foreground">
          Данные хранятся на серверах в России в соответствии с 152-ФЗ.
        </p>
      </div>
      <div className="relative hidden overflow-hidden bg-sidebar lg:block">
        <video
          className="absolute inset-0 size-full object-cover opacity-80"
          src="/brand/hero.mp4"
          poster="/brand/hero.jpg"
          autoPlay
          muted
          loop
          playsInline
          aria-hidden
        />
        <div className="absolute inset-0 bg-gradient-to-t from-black/85 via-black/30 to-black/10" />
        <div className="absolute inset-x-0 bottom-0 p-12 text-white">
          <p className="max-w-md text-3xl font-bold leading-tight tracking-tight">
            Видите, каких клиентов можете потерять, — с&nbsp;первой недели.
          </p>
          <p className="mt-3 max-w-md text-sm text-white/70">
            Клиенты, абонементы, посещения по QR, расписание и список «в зоне риска» в одном кабинете.
          </p>
        </div>
      </div>
    </div>
  );
}
