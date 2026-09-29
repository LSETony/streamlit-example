"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { UserPlus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Field, Input, NativeSelect } from "@/components/ui/input";
import { Alert, Avatar } from "@/components/ui/misc";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { changeStaffRole, inviteStaff, setStaffActive } from "@/app/actions/staff";
import type { Role } from "@/lib/types";
import { ROLE_LABEL } from "@/lib/types";

export const ROLE_HINT: Record<Role, string> = {
  owner: "Всё, включая тарифы, настройки, сотрудников и журнал",
  admin: "Дашборд, выручка, клиенты, возвраты, расписание",
  reception: "Клиенты, продажа, визиты, записи. Без выручки и настроек",
};

export function InviteForm({ onDone, compact }: { onDone?: () => void; compact?: boolean }) {
  const [error, setError] = useState<string | null>(null);
  const [pending, start] = useTransition();
  return (
    <form className="grid gap-4" action={(f) => start(async () => {
      setError(null);
      const r = await inviteStaff(f);
      if (!r.ok) return setError(r.error.message);
      toast.success(`Приглашение отправлено на ${f.get("email")}`);
      onDone?.();
    })}>
      <div className={compact ? "grid gap-3 sm:grid-cols-[1fr_1fr_160px_auto] sm:items-end" : "grid gap-4"}>
        <Field label="Имя"><Input name="full_name" required placeholder="Анна Смирнова" /></Field>
        <Field label="Email"><Input name="email" type="email" required placeholder="anna@example.ru" /></Field>
        <Field label="Роль">
          <NativeSelect name="role" defaultValue="reception">
            <option value="reception">Ресепшен</option>
            <option value="admin">Администратор</option>
            <option value="owner">Владелец</option>
          </NativeSelect>
        </Field>
        {compact ? <Button type="submit" disabled={pending}>{pending ? "Отправляем…" : "Пригласить"}</Button> : null}
      </div>
      {error ? <Alert variant="danger">{error}</Alert> : null}
      {!compact ? <DialogFooter><Button type="submit" disabled={pending}>{pending ? "Отправляем…" : "Отправить приглашение"}</Button></DialogFooter> : null}
    </form>
  );
}

export function StaffManager({ staff, meId, readOnly }: {
  staff: { id: string; email: string; role: Role; full_name: string; active: boolean; user_id: string | null }[]; meId: string; readOnly: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [, start] = useTransition();
  const act = (fn: () => Promise<{ ok: boolean; error?: { message: string } }>) => start(async () => {
    const r = await fn();
    if (!r.ok) toast.error(r.error!.message); else router.refresh();
  });
  return (
    <>
      <div className="mb-3 flex items-center justify-between gap-3"><p className="pl-1 text-sm text-muted-foreground">В команде: <b className="text-foreground">{staff.filter((s) => s.active).length}</b></p><Button onClick={() => setOpen(true)} disabled={readOnly}><UserPlus /> Пригласить</Button></div>
      <Card>
        <Table>
          <THead><TR><TH>Сотрудник</TH><TH>Роль</TH><TH>Статус</TH><TH /></TR></THead>
          <TBody>
            {staff.map((s) => (
              <TR key={s.id} className={s.active ? "" : "opacity-60"}>
                <TD>
                  <div className="flex items-center gap-3">
                    <Avatar name={s.full_name} className="size-8 text-xs" />
                    <div><p className="font-medium">{s.full_name}{s.id === meId ? " (вы)" : ""}</p><p className="text-xs text-muted-foreground">{s.email}</p></div>
                  </div>
                </TD>
                <TD>
                  {s.id === meId || readOnly ? ROLE_LABEL[s.role] : (
                    <NativeSelect value={s.role} onChange={(e) => act(() => changeStaffRole(s.id, e.target.value as Role))} className="h-8 w-44" aria-label="Роль">
                      {(Object.keys(ROLE_LABEL) as Role[]).map((r) => <option key={r} value={r}>{ROLE_LABEL[r]}</option>)}
                    </NativeSelect>
                  )}
                </TD>
                <TD>{s.active ? <Badge variant="success">Активен</Badge> : <Badge variant="outline">Отключён</Badge>}</TD>
                <TD className="text-right">
                  {s.id !== meId && !readOnly ? (
                    <Button size="sm" variant="ghost" onClick={() => act(() => setStaffActive(s.id, !s.active))}>{s.active ? "Отключить" : "Включить"}</Button>
                  ) : null}
                </TD>
              </TR>
            ))}
          </TBody>
        </Table>
      </Card>
      <div className="mt-6 grid gap-2 text-sm text-muted-foreground sm:grid-cols-3">
        {(Object.keys(ROLE_HINT) as Role[]).map((r) => <p key={r}><b className="text-foreground">{ROLE_LABEL[r]}:</b> {ROLE_HINT[r]}</p>)}
      </div>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Пригласить сотрудника</DialogTitle>
            <DialogDescription>Сотрудник получит письмо со ссылкой, задаст пароль и войдёт в кабинет.</DialogDescription>
          </DialogHeader>
          <InviteForm onDone={() => { setOpen(false); router.refresh(); }} />
        </DialogContent>
      </Dialog>
    </>
  );
}
