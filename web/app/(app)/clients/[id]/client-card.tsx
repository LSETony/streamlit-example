"use client";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { toast } from "@/lib/toast";
import { CheckCircle2, ChevronLeft, Pencil, ShoppingCart, Smartphone, Snowflake, Trash2, RotateCcw, AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Table, TBody, TD, TH, THead, TR } from "@/components/ui/table";
import { Alert, Avatar, EmptyState } from "@/components/ui/misc";
import { Textarea } from "@/components/ui/input";
import { MembershipStatusBadge, PaymentStatusBadge, RiskBadge } from "@/components/status";
import { SellDialog } from "@/components/sell-dialog";
import { checkinManual } from "@/app/actions/visits";
import { endFreeze, cancelMembership } from "@/app/actions/memberships";
import { saveNote } from "@/app/actions/clients";
import { date, dateTime, phone } from "@/lib/format";
import { useRegion } from "@/lib/region-context";
import type { Client, Membership, RiskRow, Role } from "@/lib/types";
import { METHOD_LABEL } from "@/lib/types";
import type { BookingRow, FreezeRow, PaymentRow, VisitRow } from "./page";
import { FreezeDialog } from "./freeze-dialog";
import { RefundDialog } from "./refund-dialog";
import { EditClientDialog, DeleteClientDialog } from "./edit-client";
import { useT } from "@/lib/i18n/client";
import { paymentDescription } from "@/lib/i18n/core";

const BOOKING_LABEL = { booked: "Записан", cancelled: "Отменена", attended: "Пришёл", no_show: "Не пришёл" } as const;

export function ClientCard(props: {
  client: Client; memberships: Membership[]; freezes: FreezeRow[]; visits: VisitRow[]; payments: PaymentRow[];
  bookings: BookingRow[]; risk: RiskRow | null; role: Role; gymId: string; timezone: string; today: string; readOnly: boolean; openSell: boolean;
}) {
  const { client, memberships, freezes, visits, payments, bookings, risk, role, timezone, today, readOnly } = props;
  const t = useT();
  const { money } = useRegion();
  const router = useRouter();
  const [sell, setSell] = useState<null | { renew: Membership | null }>(props.openSell ? { renew: null } : null);
  const [freezeFor, setFreezeFor] = useState<Membership | null>(null);
  const [refundFor, setRefundFor] = useState<PaymentRow | null>(null);
  const [edit, setEdit] = useState(false);
  const [del, setDel] = useState(false);
  const [note, setNote] = useState(client.note ?? "");
  const [pending, start] = useTransition();
  const canMoney = role !== "reception";

  const current = memberships.find((m) => ["active", "frozen"].includes(m.status) && m.starts_on <= today && m.ends_on >= today) ?? null;
  const latest = memberships.find((m) => ["active", "frozen"].includes(m.status)) ?? null;
  const currentFreeze = current ? freezes.find((f) => f.membership_id === current.id && f.from_date <= today && f.to_date >= today) : null;

  function doCheckin() {
    start(async () => {
      const res = await checkinManual(client.id);
      if (!res.ok) return void toast.error(res.error.message);
      if (res.data.ok) toast.success(res.data.repeat ? "Визит уже отмечен" : "Визит отмечен");
      else toast.error(res.data.message);
      router.refresh();
    });
  }

  return (
    <div className="grid gap-6 [&>*]:min-w-0">
      <Link href="/clients" className="-mb-2 -ml-1.5 inline-flex w-fit items-center gap-0.5 text-[17px] text-tint-text active:opacity-60">
        <ChevronLeft className="size-6" strokeWidth={2.25} /> {t("Клиенты")}
      </Link>
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div className="flex min-w-0 items-center gap-4">
          <Avatar name={client.full_name} src={client.photo_url} className="size-16 text-xl" />
          <div className="grid min-w-0 gap-1">
            <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.02em]">{client.full_name}</h1>
            <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
              <a href={`tel:${client.phone}`} className="tabular hover:text-foreground">{phone(client.phone)}</a>
              {client.email ? <span>· {client.email}</span> : null}
              {client.user_id ? (
                <Badge variant="brand"><Smartphone className="size-3" /> В приложении</Badge>
              ) : (
                <Badge variant="outline">Не в приложении</Badge>
              )}
              {client.tags.map((t) => <Badge key={t}>{t}</Badge>)}
            </div>
          </div>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button variant="outline" onClick={() => setEdit(true)} disabled={readOnly}><Pencil /> Изменить</Button>
          <Button variant="outline" onClick={doCheckin} disabled={pending || readOnly}><CheckCircle2 /> Отметить визит</Button>
          <Button onClick={() => setSell({ renew: latest && latest.ends_on >= today ? latest : null })} disabled={readOnly}>
            <ShoppingCart /> {latest && latest.ends_on >= today ? "Продлить" : "Продать абонемент"}
          </Button>
        </div>
      </div>

      {risk ? (
        <Alert variant="warning" className="flex items-center gap-2">
          <AlertTriangle className="size-4 shrink-0" />
          <RiskBadge reason={risk.reason} /> <span>{t(risk.reason_text)}</span>
        </Alert>
      ) : null}

      <div className="grid gap-4 sm:grid-cols-3">
        <Stat label="Абонемент">
          {current ? (
            <>
              <span className="font-semibold">{current.plan_name}</span>
              <span className="text-sm text-muted-foreground">
                {currentFreeze ? t("заморожен до {date}", { date: date(currentFreeze.to_date) }) : t("до {date}", { date: date(current.ends_on) })}
                {current.visits_left !== null ? ` · ${current.visits_left} ${t.n(current.visits_left, "визит|визита|визитов")}` : ""}
              </span>
            </>
          ) : (
            <>
              <span className="font-semibold text-muted-foreground">{t("Нет действующего")}</span>
              <button className="w-fit cursor-pointer text-sm font-medium underline-offset-2 hover:underline disabled:opacity-50" onClick={() => setSell({ renew: null })} disabled={readOnly}>{t("Продать →")}</button>
            </>
          )}
        </Stat>
        <Stat label="Последний визит">
          <span className="font-semibold">{client.last_visit_at ? dateTime(client.last_visit_at, timezone) : "—"}</span>
          <span className="text-sm text-muted-foreground">{visits.length} {t.n(visits.length, "визит|визита|визитов")} {t("в истории")}</span>
        </Stat>
        <Stat label="Клиент с">
          <span className="font-semibold">{date(client.created_at.slice(0, 10))}</span>
          <span className="text-sm text-muted-foreground">{client.source ? t(client.source) : t("источник не указан")}</span>
        </Stat>
      </div>

      <Tabs defaultValue="memberships">
        <TabsList>
          <TabsTrigger value="memberships">Абонементы</TabsTrigger>
          <TabsTrigger value="visits">Визиты</TabsTrigger>
          {canMoney ? <TabsTrigger value="payments">Оплаты</TabsTrigger> : null}
          <TabsTrigger value="bookings">Записи</TabsTrigger>
          <TabsTrigger value="notes">Заметки</TabsTrigger>
        </TabsList>

        <TabsContent value="memberships">
          {memberships.length === 0 ? (
            <EmptyState title="Абонементов пока нет" action={<Button onClick={() => setSell({ renew: null })} disabled={readOnly}><ShoppingCart /> Продать абонемент</Button>} />
          ) : (
            <Card>
              <Table>
                <THead><TR><TH>Тариф</TH><TH>Период</TH><TH>Статус</TH><TH>Визиты</TH>{canMoney ? <TH>Цена</TH> : null}<TH /></TR></THead>
                <TBody>
                  {memberships.map((m) => {
                    const mf = freezes.filter((f) => f.membership_id === m.id);
                    const freezeLeft = m.freeze_days_max - m.freeze_days_used;
                    const live = ["active", "frozen"].includes(m.status) && m.ends_on >= today;
                    return (
                      <TR key={m.id}>
                        <TD>
                          <span className="font-medium">{m.plan_name}</span>
                          {m.imported ? <span className="ml-2 text-xs text-muted-foreground">{t("импорт")}</span> : null}
                          {mf.map((f) => (
                            <div key={f.id} className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                              <Snowflake className="size-3" /> {date(f.from_date)} – {date(f.to_date)} ({f.days} {t("дн.")}){f.reason ? ` · ${f.reason}` : ""}
                              {f.to_date >= today && !readOnly ? (
                                <button className="cursor-pointer underline hover:text-foreground" onClick={() => start(async () => {
                                  const r = await endFreeze(f.id, client.id);
                                  if (r.ok) { toast.success("Заморозка снята"); router.refresh(); } else toast.error(r.error.message);
                                })}>{t("снять")}</button>
                              ) : null}
                            </div>
                          ))}
                        </TD>
                        <TD className="whitespace-nowrap tabular">{date(m.starts_on)} – {date(m.ends_on)}</TD>
                        <TD><MembershipStatusBadge status={m.status} /></TD>
                        <TD className="tabular">{m.visits_left ?? "∞"}</TD>
                        {canMoney ? <TD className="tabular">{money(m.price_paid)}</TD> : null}
                        <TD className="text-right">
                          {live && !readOnly ? (
                            <div className="flex justify-end gap-1">
                              <Button size="sm" variant="ghost" onClick={() => setFreezeFor(m)} disabled={freezeLeft <= 0} title={t("Доступно дней заморозки: {n}", { n: freezeLeft })}>
                                <Snowflake /> Заморозить
                              </Button>
                              {canMoney ? (
                                <Button size="sm" variant="ghost" onClick={() => {
                                  if (!confirm(t("Отменить абонемент? Деньги можно вернуть на вкладке «Оплаты»."))) return;
                                  start(async () => {
                                    const r = await cancelMembership(m.id, client.id);
                                    if (r.ok) { toast.success("Абонемент отменён"); router.refresh(); } else toast.error(r.error.message);
                                  });
                                }}>Отменить</Button>
                              ) : null}
                            </div>
                          ) : null}
                        </TD>
                      </TR>
                    );
                  })}
                </TBody>
              </Table>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="visits">
          {visits.length === 0 ? <EmptyState title="Визитов пока нет" /> : (
            <Card>
              <Table>
                <THead><TR><TH>Пришёл</TH><TH>Ушёл</TH><TH>Отметка</TH></TR></THead>
                <TBody>
                  {visits.map((v) => (
                    <TR key={v.id}>
                      <TD className="tabular">{dateTime(v.checked_in_at, timezone)}</TD>
                      <TD className="tabular text-muted-foreground">{v.checked_out_at ? dateTime(v.checked_out_at, timezone) : t("в зале")}</TD>
                      <TD><Badge variant="outline">{v.method === "qr" ? "QR" : "Вручную"}</Badge></TD>
                    </TR>
                  ))}
                </TBody>
              </Table>
            </Card>
          )}
        </TabsContent>

        {canMoney ? (
          <TabsContent value="payments">
            {payments.length === 0 ? <EmptyState title="Оплат пока нет" /> : (
              <Card>
                <Table>
                  <THead><TR><TH>Дата</TH><TH>Сумма</TH><TH>Способ</TH><TH>Статус</TH><TH>Назначение</TH><TH /></TR></THead>
                  <TBody>
                    {payments.map((p) => (
                      <TR key={p.id}>
                        <TD className="tabular whitespace-nowrap">{dateTime(p.paid_at ?? p.created_at, timezone)}</TD>
                        <TD className={p.refund_of_id ? "tabular text-destructive" : "tabular font-medium"}>{p.refund_of_id ? "−" : ""}{money(p.amount)}</TD>
                        <TD>{t(METHOD_LABEL[p.method])}</TD>
                        <TD><PaymentStatusBadge status={p.status} isRefund={!!p.refund_of_id} /></TD>
                        <TD className="text-muted-foreground">{paymentDescription(t, p.description)}</TD>
                        <TD className="text-right">
                          {!p.refund_of_id && p.status === "succeeded" && !readOnly ? (
                            <Button size="sm" variant="ghost" onClick={() => setRefundFor(p)}><RotateCcw /> Возврат</Button>
                          ) : p.status === "pending" && p.confirmation_url ? (
                            <Button size="sm" variant="ghost" onClick={() => { navigator.clipboard.writeText(p.confirmation_url!); toast.success("Ссылка скопирована"); }}>Ссылка</Button>
                          ) : null}
                        </TD>
                      </TR>
                    ))}
                  </TBody>
                </Table>
              </Card>
            )}
          </TabsContent>
        ) : null}

        <TabsContent value="bookings">
          {bookings.length === 0 ? <EmptyState title="Записей на занятия нет" /> : (
            <Card>
              <Table>
                <THead><TR><TH>Занятие</TH><TH>Когда</TH><TH>Статус</TH><TH>Канал</TH></TR></THead>
                <TBody>
                  {bookings.map((b) => (
                    <TR key={b.id}>
                      <TD className="font-medium">{b.schedule_items?.title}{b.schedule_items?.trainer_name ? <span className="font-normal text-muted-foreground"> · {b.schedule_items.trainer_name}</span> : null}</TD>
                      <TD className="tabular">{b.schedule_items ? dateTime(b.schedule_items.starts_at, timezone) : "—"}</TD>
                      <TD><Badge variant={b.status === "attended" ? "success" : b.status === "booked" ? "info" : b.status === "no_show" ? "danger" : "outline"}>{t(BOOKING_LABEL[b.status])}</Badge></TD>
                      <TD className="text-muted-foreground">{b.channel === "app" ? t("Приложение") : t("Ресепшен")}</TD>
                    </TR>
                  ))}
                </TBody>
              </Table>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="notes">
          <Card>
            <CardContent className="grid gap-4 pt-5">
              <Textarea value={note} onChange={(e) => setNote(e.target.value)} rows={5} placeholder="Цели, пожелания, договорённости…" disabled={readOnly} />
              <div className="flex flex-wrap items-center justify-between gap-3">
                <div className="grid gap-0.5 text-xs text-muted-foreground">
                  <span>{t("Согласие на обработку данных:")} {client.consent_pd_at ? dateTime(client.consent_pd_at, timezone) : t("нет")}</span>
                  <span>{t("Согласие на рассылки:")} {client.consent_marketing_at ? dateTime(client.consent_marketing_at, timezone) : t("нет")}</span>
                </div>
                <div className="flex gap-2">
                  {canMoney ? <Button variant="ghost" className="text-destructive" onClick={() => setDel(true)}><Trash2 /> Удалить по запросу</Button> : null}
                  <Button onClick={() => start(async () => {
                    const r = await saveNote(client.id, note);
                    if (r.ok) toast.success("Заметка сохранена"); else toast.error(r.error.message);
                  })} disabled={pending || readOnly || note === (client.note ?? "")}>Сохранить</Button>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {sell ? (
        <SellDialog open onOpenChange={(v) => !v && setSell(null)} gymId={props.gymId} client={client} today={today}
          renew={sell.renew ? { id: sell.renew.id, ends_on: sell.renew.ends_on, plan_id: sell.renew.plan_id } : null}
          onDone={() => { setSell(null); router.replace(`/clients/${client.id}`); router.refresh(); }} />
      ) : null}
      {freezeFor ? <FreezeDialog membership={freezeFor} clientId={client.id} today={today} onClose={() => { setFreezeFor(null); router.refresh(); }} /> : null}
      {refundFor ? <RefundDialog payment={refundFor} clientId={client.id} onClose={() => { setRefundFor(null); router.refresh(); }} /> : null}
      {edit ? <EditClientDialog client={client} onClose={() => { setEdit(false); router.refresh(); }} /> : null}
      {del ? <DeleteClientDialog client={client} onClose={() => setDel(false)} /> : null}
    </div>
  );
}

function Stat({ label, children }: { label: string; children: React.ReactNode }) {
  const t = useT();
  return (
    <Card className="grid content-start gap-1 p-4 [&>span:nth-child(2)]:text-[17px]">
      <span className="text-xs text-muted-foreground">{t(label)}</span>
      {children}
    </Card>
  );
}
