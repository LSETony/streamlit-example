-- Автотесты бизнес-правил (критерии приёмки раздела 5): абонементы, заморозки, визиты, QR, брони,
-- уведомления, оплаты и возвраты, импорт, обезличивание, «только чтение», дашборд и «зона риска».
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;

-- Генерация QR так же, как это делает приложение (раздел 6)
create or replace function tests.qr(p_device uuid, p_secret text, p_shift_steps int default 0) returns text
language plpgsql as $$
declare
  v_t bigint := floor(extract(epoch from now()) / 30) + p_shift_steps;
  v_msg text := 'CORE1:' || p_device || ':' || v_t;
begin
  return v_msg || ':' || left(encode(extensions.hmac(convert_to(v_msg, 'UTF8'), decode(p_secret, 'hex'), 'sha256'), 'hex'), 32);
end $$;
grant execute on all functions in schema tests to authenticated, service_role;

select tests.put('today_a', null) where false;
create or replace function tests.today() returns date language sql stable as $$ select (now() at time zone 'Europe/Moscow')::date $$;
grant execute on function tests.today to authenticated;

-- ===========================================================================
-- 5.3 Абонементы
-- ===========================================================================
select tests.login(tests.id('reception_a'));
select tests.expect_error(format('select public.sell_membership(%L, %L, ''cash'')', tests.id('client_a1'), tests.id('plan_month')),
                          'MEMBERSHIP_OVERLAP');
select tests.expect_error(format('select public.sell_membership(%L, %L, ''online'')', tests.id('client_a1'), tests.id('plan_month')),
                          'USE_ONLINE_PAYMENT');
do $$
declare
  cur public.memberships;
  r jsonb;
begin
  select * into cur from public.memberships where client_id = tests.id('client_a1') and status = 'active';
  -- фикстура: месяц с сегодняшнего дня + заморозка на 3 дня
  perform tests.assert(cur.ends_on = tests.today() + 29 + 3, 'заморозка должна сдвинуть окончание на 3 дня');
  perform tests.assert(cur.freeze_days_used = 3, 'использовано 3 дня заморозки');
  r := public.sell_membership(tests.id('client_a1'), tests.id('plan_month'), 'card', null, cur.id);
  perform tests.assert((r -> 'membership' ->> 'starts_on')::date = cur.ends_on + 1, 'продление начинается после окончания текущего');
  perform tests.assert((select renewed_from_id from public.memberships where id = (r -> 'membership' ->> 'id')::uuid) = cur.id,
                       'связь через renewed_from_id');
  perform set_config('t.renewal', r -> 'membership' ->> 'id', true);
end $$;
reset role;

-- Цена проданного абонемента не меняется при изменении тарифа
select tests.login(tests.id('owner_a'));
update public.membership_plans set price = 999900 where id = tests.id('plan_month');
select tests.assert((select bool_and(price_paid = 300000) from public.memberships where plan_id = tests.id('plan_month')),
                    'цена фиксируется на момент продажи');
reset role;

-- Заморозка: лимит, сдвиг продления, запрет в прошлом, досрочное окончание
select tests.login(tests.id('reception_a'));
select tests.put('m_a1', (select id from public.memberships where client_id = tests.id('client_a1') and renewed_from_id is null and status = 'active'));
select tests.expect_error(format('select public.freeze_membership(%L, %L::date, %L::date)', tests.id('m_a1'),
                                 tests.today() + 10, tests.today() + 21), 'FREEZE_LIMIT');   -- 12 дн. при остатке 11
select tests.expect_error(format('select public.freeze_membership(%L, %L::date, %L::date)', tests.id('m_a1'),
                                 tests.today() - 1, tests.today() + 1), 'INVALID_DATE');
select tests.expect_error(format('select public.freeze_membership(%L, %L::date, %L::date)', tests.id('m_a1'),
                                 tests.today() + 6, tests.today() + 8), 'FREEZE_OVERLAP');
do $$
declare
  before_renewal date;
  r jsonb;
begin
  select starts_on into before_renewal from public.memberships where id = tests.id('renewal');
  r := public.freeze_membership(tests.id('m_a1'), tests.today() + 10, tests.today() + 20, 'болезнь');
  perform tests.assert((select starts_on from public.memberships where id = tests.id('renewal')) = before_renewal + 11,
                       'продление сдвигается вместе с заморозкой');
  perform tests.assert((r -> 'membership' ->> 'freeze_days_left')::int = 0, 'лимит заморозки исчерпан');
  -- досрочно отменяем будущую заморозку — дни возвращаются
  r := public.end_freeze((r ->> 'freeze_id')::uuid);
  perform tests.assert((r ->> 'days_returned')::int = 11, 'возвращено 11 дней');
  perform tests.assert((select starts_on from public.memberships where id = tests.id('renewal')) = before_renewal,
                       'продление вернулось на место');
end $$;
reset role;

-- ===========================================================================
-- 5.4 Визиты
-- ===========================================================================
select tests.login(tests.id('reception_a'));
do $$
declare
  r jsonb;
begin
  -- повторный скан за 10 минут не списывает второй визит (FR-4.4)
  r := public.checkin_manual(tests.id('client_a2'));
  perform tests.assert((r ->> 'ok')::boolean and (r ->> 'repeat')::boolean, 'повтор должен быть ok+repeat');
  perform tests.assert((r -> 'membership' ->> 'visits_left')::int = 9, 'повтор не списывает визит');
end $$;
reset role;
update public.visits set checked_in_at = now() - interval '11 minutes' where client_id = tests.id('client_a2');
select tests.login(tests.id('reception_a'));
do $$
declare
  r jsonb;
begin
  r := public.checkin_manual(tests.id('client_a2'));
  perform tests.assert((r ->> 'ok')::boolean and not (r ->> 'repeat')::boolean, 'через 11 минут — новый визит');
  perform tests.assert((r -> 'membership' ->> 'visits_left')::int = 8, 'списан второй визит');
  perform tests.assert((select count(*) from public.visits where client_id = tests.id('client_a2') and checked_out_at is null) = 1,
                       'предыдущий визит закрыт');
end $$;
-- клиент без абонемента
with x as (insert into public.clients (gym_id, full_name, phone) values (tests.id('gym_a'), 'Без Абонемента', '+79160000003') returning id)
select tests.put('client_a3', id) from x;
select tests.assert((public.checkin_manual(tests.id('client_a3')) ->> 'code') = 'NO_ACTIVE_MEMBERSHIP', 'нет абонемента — красный экран');
select tests.assert((public.checkin_manual(tests.id('client_a3')) -> 'client' ->> 'full_name') = 'Без Абонемента', 'на красном экране — имя клиента');
-- заморожен сегодня
with x as (insert into public.clients (gym_id, full_name, phone) values (tests.id('gym_a'), 'Заморожен Сегодня', '+79160000004') returning id)
select tests.put('client_a4', id) from x;
select public.sell_membership(tests.id('client_a4'), tests.id('plan_month'), 'cash');
select public.freeze_membership((select id from public.memberships where client_id = tests.id('client_a4')), tests.today(), tests.today() + 2);
select tests.assert((public.checkin_manual(tests.id('client_a4')) ->> 'code') = 'MEMBERSHIP_FROZEN', 'заморожен — красный экран');
select tests.assert((select status from public.memberships where client_id = tests.id('client_a4')) = 'frozen', 'статус frozen');
reset role;
-- закончились визиты
update public.memberships set visits_left = 0 where client_id = tests.id('client_a2');
update public.visits set checked_in_at = now() - interval '1 hour' where client_id = tests.id('client_a2');
select tests.login(tests.id('reception_a'));
select tests.assert((public.checkin_manual(tests.id('client_a2')) ->> 'code') = 'NO_VISITS_LEFT', 'кончились визиты');
reset role;
update public.memberships set visits_left = 8 where client_id = tests.id('client_a2');

-- ===========================================================================
-- Раздел 6: динамический QR
-- ===========================================================================
select tests.put('device', (select id from public.client_devices where user_id = tests.id('client_user') and revoked_at is null));
select set_config('t.secret', (select qr_secret from public.client_devices where id = tests.id('device')), false);
select set_config('t.qr_ok', tests.qr(tests.id('device'), current_setting('t.secret')), false);
select set_config('t.qr_old', tests.qr(tests.id('device'), current_setting('t.secret'), -3), false);
select set_config('t.qr_future', tests.qr(tests.id('device'), current_setting('t.secret'), 1), false);

select tests.login(tests.id('reception_a'));
do $$
declare
  r jsonb;
begin
  r := public.checkin_qr(tests.id('gym_a'), current_setting('t.qr_old'));
  perform tests.assert(r ->> 'code' = 'QR_EXPIRED', 'скриншот QR старше 60 секунд не проходит: ' || r::text);
  r := public.checkin_qr(tests.id('gym_a'), current_setting('t.qr_ok') || 'x');
  perform tests.assert(r ->> 'code' = 'QR_INVALID', 'искажённый QR');
  r := public.checkin_qr(tests.id('gym_a'), replace(current_setting('t.qr_ok'), right(current_setting('t.qr_ok'), 4), '0000'));
  perform tests.assert(r ->> 'code' = 'QR_INVALID', 'подпись не совпадает');
  r := public.checkin_qr(tests.id('gym_a'), 'hello world');
  perform tests.assert(r ->> 'code' = 'QR_INVALID', 'чужой QR');
  r := public.checkin_qr(tests.id('gym_a'), current_setting('t.qr_ok'));
  perform tests.assert((r ->> 'ok')::boolean and r -> 'client' ->> 'id' = tests.id('client_a1')::text, 'валидный QR: ' || r::text);
  perform tests.assert((select method from public.visits where id = (r ->> 'visit_id')::uuid) = 'qr', 'визит по QR');
  r := public.checkin_qr(tests.id('gym_a'), current_setting('t.qr_future'));
  perform tests.assert((r ->> 'repeat')::boolean, 'повторный скан — без второго визита');
end $$;
reset role;
select tests.login(tests.id('owner_b'));
select tests.assert((public.checkin_qr(tests.id('gym_b'), current_setting('t.qr_ok')) ->> 'code') = 'CLIENT_NOT_FOUND',
                    'QR клиента чужого зала');
reset role;
-- новый телефон: старый секрет отзывается
select tests.login(tests.id('client_user'));
select public.register_device('ios', 'apns-token-2');
reset role;
select tests.login(tests.id('reception_a'));
select tests.assert((public.checkin_qr(tests.id('gym_a'), current_setting('t.qr_ok')) ->> 'code') = 'QR_INVALID',
                    'QR со старого телефона не проходит');
reset role;

-- ===========================================================================
-- 5.5 Расписание и бронь
-- ===========================================================================
select tests.login(tests.id('reception_a'));
do $$
declare
  r jsonb;
begin
  r := public.book_class(tests.id('class_a'), tests.id('client_a2'));
  perform tests.assert((r ->> 'spots_left')::int = 0, 'осталось 0 мест');
end $$;
select tests.expect_error(format('select public.book_class(%L, %L)', tests.id('class_a'), tests.id('client_a3')), 'CLASS_FULL');
select tests.expect_error(format('select public.book_class(%L, %L)', tests.id('class_a'), tests.id('client_a1')), 'ALREADY_BOOKED');
reset role;
select tests.assert((select count(*) from public.notifications_outbox where kind = 'booking_confirmed') = 2, 'подтверждения записи в очереди');
select tests.assert((select count(*) from public.notifications_outbox where kind = 'class_reminder') = 2, 'напоминания за 2 часа в очереди');

-- клиент отменяет свою запись из приложения и записывается снова
select tests.put('booking_a2', (select id from public.bookings where client_id = tests.id('client_a2')));
select tests.login(tests.id('client_user'));
select public.cancel_booking((select id from public.bookings where client_id = tests.id('client_a1') and schedule_item_id = tests.id('class_a')));
select tests.assert((public.book_class(tests.id('class_a')) ->> 'spots_left')::int = 0, 'запись из приложения');
select tests.expect_error(format('select public.cancel_booking(%L)', tests.id('booking_a2')), 'FORBIDDEN');
reset role;

-- поздняя отмена (занятие через час, отмена не позже чем за 2 часа)
select tests.login(tests.id('owner_a'));
select public.create_schedule_series(tests.id('gym_a'), 'Скоро', ((now() + interval '1 hour') at time zone 'Europe/Moscow')::timestamp, 45, 5);
select tests.put('class_soon', (select id from public.schedule_items where title = 'Скоро'));
select public.book_class(tests.id('class_soon'), tests.id('client_a1'));
reset role;
select tests.login(tests.id('client_user'));
select tests.expect_error(format('select public.cancel_booking(%L)',
  (select id from public.bookings where schedule_item_id = tests.id('class_soon'))), 'CANCEL_TOO_LATE');
reset role;
-- отмена занятия залом уведомляет записавшихся
select tests.login(tests.id('admin_a'));
select tests.assert((public.cancel_class(tests.id('class_soon'), 'тренер заболел') ->> 'notified')::int = 1, 'уведомлён 1 записавшийся');
select tests.expect_error(format('select public.book_class(%L, %L)', tests.id('class_soon'), tests.id('client_a2')), 'CLASS_CANCELLED');
reset role;
select tests.assert((select count(*) from public.notifications_outbox where kind = 'class_cancelled') = 1, 'уведомление об отмене занятия');
select tests.assert(not exists (select 1 from public.notifications_outbox where kind = 'class_reminder' and status = 'queued'
                      and data ->> 'schedule_item_id' = tests.id('class_soon')::text), 'напоминаний об отменённом занятии нет');
select tests.assert((select count(*) from public.notifications_outbox where kind = 'class_reminder' and status = 'skipped') = 1,
                    'напоминание отменённой записи снято');

-- повторяющееся занятие
select tests.login(tests.id('owner_a'));
select tests.assert((public.create_schedule_series(tests.id('gym_a'), 'Пилатес', (tests.today() + 1 + time '10:00')::timestamp, 55, 8,
                      'class', null, 'Ника', array[1,3,5], tests.today() + 28) ->> 'created')::int between 11 and 13,
                    'серия пн/ср/пт на 4 недели');
reset role;

-- без абонемента из приложения записаться нельзя
select tests.login(tests.id('new_user'));
select tests.put('client_new', public.join_gym(tests.id('gym_a'), 'Новый Клиент'));
select tests.expect_error(format('select public.book_class(%L)',
  (select id from public.schedule_items where title = 'Пилатес' order by starts_at limit 1)), 'NO_ACTIVE_MEMBERSHIP');
reset role;
select tests.assert((select source from public.clients where id = tests.id('client_new')) = 'приложение core.', 'источник — приложение');

-- ===========================================================================
-- 5.9 Уведомления: согласие и тихие часы
-- ===========================================================================
do $$
declare
  v uuid;
  v_send timestamptz;
begin
  -- маркетинговое без согласия не ставится
  v := private.enqueue_notification(tests.id('client_a1'), 'membership_expiring', false, 't', 'b');
  perform tests.assert(v is null, 'без согласия на рассылки — не отправляем');
  -- ночью не отправляем: 23:30 по времени зала → 9:00 следующего дня
  v := private.enqueue_notification(tests.id('client_a2'), 'membership_expiring', false, 't', 'b', '{}',
                                    (tests.today() + time '23:30') at time zone 'Europe/Moscow');
  select send_after into v_send from public.notifications_outbox where id = v;
  perform tests.assert(v_send = (tests.today() + 1 + time '09:00') at time zone 'Europe/Moscow', 'перенос на 9:00');
end $$;

-- ===========================================================================
-- 5.6 Онлайн-оплата: идемпотентный webhook
-- ===========================================================================
select tests.login(tests.id('client_user'));
select tests.expect_error(format('select public.start_online_purchase(%L)', tests.id('plan_10')), 'PLAN_NOT_FOR_SALE');
select set_config('t.purchase', public.start_online_purchase(tests.id('plan_month'))::text, false);
reset role;
do $$
declare
  p jsonb := current_setting('t.purchase')::jsonb;
  r jsonb;
  m public.memberships;
begin
  perform tests.assert((select status from public.memberships where id = (p ->> 'membership_id')::uuid) = 'pending', 'ждёт оплаты');
  perform tests.assert((p ->> 'amount')::bigint = 999900, 'цена текущего тарифа');
  perform public.attach_provider_payment((p ->> 'payment_id')::uuid, 'yk-100', 'https://yoomoney.ru/checkout/x');
  r := public.confirm_online_payment('yookassa', 'yk-100', 'succeeded');
  perform tests.assert(r ->> 'result' = 'activated', 'абонемент активирован');
  r := public.confirm_online_payment('yookassa', 'yk-100', 'succeeded');
  perform tests.assert(r ->> 'result' = 'already_processed', 'повторный webhook — без эффекта');
  perform tests.assert((select count(*) from public.payments where provider_payment_id = 'yk-100') = 1, 'одна оплата');
  select * into m from public.memberships where id = (p ->> 'membership_id')::uuid;
  perform tests.assert(m.status = 'active', 'статус active');
  -- встаёт за последним абонементом (продлением), без пересечений
  perform tests.assert(m.starts_on = (select ends_on + 1 from public.memberships where id = tests.id('renewal')), 'встаёт за продлением');
  r := public.confirm_online_payment('yookassa', 'unknown', 'succeeded');
  perform tests.assert(r ->> 'result' = 'unknown_payment', 'неизвестный платёж');
end $$;
-- отменённая оплата
select tests.login(tests.id('reception_a'));
select set_config('t.purchase2', public.start_online_purchase(tests.id('plan_10'), tests.id('client_a3'))::text, false);
reset role;
select public.attach_provider_payment((current_setting('t.purchase2')::jsonb ->> 'payment_id')::uuid, 'yk-101');
select public.confirm_online_payment('yookassa', 'yk-101', 'canceled');
select tests.assert((select status from public.memberships where id = (current_setting('t.purchase2')::jsonb ->> 'membership_id')::uuid) = 'cancelled',
                    'неоплаченный абонемент отменён');

-- ===========================================================================
-- Возвраты (FR-6.3, FR-3.6)
-- ===========================================================================
select tests.login(tests.id('admin_a'));
select tests.put('pay_a1', (select id from public.payments where client_id = tests.id('client_a1') and method = 'cash' and refund_of_id is null));
select tests.assert((public.refund_payment(tests.id('pay_a1'), 100000) ->> 'status') = 'refunded', 'частичный возврат наличных');
select tests.expect_error(format('select public.refund_payment(%L, 250000)', tests.id('pay_a1')), 'REFUND_AMOUNT_INVALID');
select tests.assert((public.refund_payment(tests.id('pay_a1'), 200000, true) ->> 'amount')::bigint = 200000, 'остаток возвращён');
select tests.assert((select status from public.payments where id = tests.id('pay_a1')) = 'refunded', 'оплата полностью возвращена');
select tests.assert((select status from public.memberships where id = tests.id('m_a1')) = 'cancelled', 'абонемент отменён при возврате');
select set_config('t.refund_online', public.refund_payment(
  (select id from public.payments where provider_payment_id = 'yk-100'))::text, false);
select tests.assert((current_setting('t.refund_online')::jsonb ->> 'needs_provider')::boolean, 'онлайн-возврат идёт через ЮKassa');
reset role;
select public.confirm_refund((current_setting('t.refund_online')::jsonb ->> 'refund_id')::uuid, true, 'rf-1');
select tests.assert((select status from public.payments where provider_payment_id = 'yk-100') = 'refunded', 'онлайн-оплата возвращена');
select tests.assert((public.confirm_refund((current_setting('t.refund_online')::jsonb ->> 'refund_id')::uuid, true) ->> 'idempotent')::boolean,
                    'повторное подтверждение возврата — без эффекта');

-- ===========================================================================
-- 5.2 Импорт (FR-2.4) и обезличивание (FR-2.6)
-- ===========================================================================
select tests.login(tests.id('owner_a'));
do $$
declare
  r jsonb;
  rows jsonb := jsonb_build_array(
    jsonb_build_object('row', 2, 'full_name', 'Ольга Новая', 'phone', '8-926-111-22-33', 'source', 'Excel',
                       'plan_name', 'месяц', 'starts_on', tests.today() - 10, 'ends_on', tests.today() + 20),
    jsonb_build_object('row', 3, 'full_name', 'Плохой Телефон', 'phone', '12345'),
    jsonb_build_object('row', 4, 'full_name', 'Мария Сидорова-Иванова', 'phone', '89030000002'),
    jsonb_build_object('row', 5, 'full_name', 'Кривая Дата', 'phone', '+79260000005', 'birth_date', '31.02.1990'),
    jsonb_build_object('row', 6, 'full_name', 'Пётр Разовый', 'phone', '9260000006', 'ends_on', tests.today() - 40,
                       'starts_on', tests.today() - 70, 'visits_left', 2));
begin
  r := public.import_clients(tests.id('gym_a'), rows, true);
  perform tests.assert((r ->> 'created')::int = 2 and (r ->> 'updated')::int = 1 and jsonb_array_length(r -> 'errors') = 2,
                       'импорт: 2 новых, 1 обновлён, 2 ошибки: ' || r::text);
  perform tests.assert((r -> 'errors' -> 0 ->> 'row')::int = 3, 'ошибка в строке 3');
  perform tests.assert((select full_name from public.clients where id = tests.id('client_a2')) = 'Мария Сидорова-Иванова',
                       'повторный телефон обновляет клиента');
  perform tests.assert((select status from public.memberships m join public.clients c on c.id = m.client_id
                         where c.phone = '+79261112233') = 'active', 'импортирован действующий абонемент');
  perform tests.assert((select status from public.memberships m join public.clients c on c.id = m.client_id
                         where c.phone = '+79260000006') = 'expired', 'старый абонемент — expired');
  -- повторный импорт не дублирует
  r := public.import_clients(tests.id('gym_a'), rows, true);
  perform tests.assert((r ->> 'created')::int = 0 and (r ->> 'memberships')::int = 0, 'повторный импорт обновляет, а не дублирует');
end $$;

select public.anonymize_client(tests.id('client_a1'));
select tests.assert((select phone is null and full_name = 'Клиент удалён' and user_id is null and deleted_at is not null
                       from public.clients where id = tests.id('client_a1')), 'персональные данные обезличены');
select tests.assert((select count(*) from public.payments where client_id = tests.id('client_a1')) >= 3, 'оплаты сохранены для бухгалтерии');
-- номер освобождается: клиент может снова прийти в зал
insert into public.clients (gym_id, full_name, phone) values (tests.id('gym_a'), 'Иван Петров', '+79161234567');
reset role;

-- ===========================================================================
-- FR-10: после пробного периода — «только чтение»
-- ===========================================================================
update public.gyms set trial_until = current_date - 1, paid_until = null where id = tests.id('gym_a');
select tests.login(tests.id('reception_a'));
select tests.expect_error(format('select public.checkin_manual(%L)', tests.id('client_a2')), 'GYM_READ_ONLY');
select tests.expect_error(format($q$insert into public.clients (gym_id, full_name, phone) values (%L, 'X', '+79160000077')$q$,
                                 tests.id('gym_a')), '42501');
select tests.assert((select count(*) from public.clients where gym_id = tests.id('gym_a')) > 0, 'данные доступны для чтения');
reset role;
select tests.login(tests.id('platform'));
select public.admin_update_gym(tests.id('gym_a'), p_paid_until => current_date + 30);
reset role;
select tests.login(tests.id('reception_a'));
select public.checkin_manual(tests.id('client_a3')) is not null;
reset role;

-- ===========================================================================
-- 5.7 Дашборд: цифры совпадают с ручным расчётом (зал Б)
-- ===========================================================================
-- b2: закончился 16 дней назад, не продлён → отток и непродлённый
-- b3: закончился 10 дней назад, продлён через 5 дней (оплата 4 000 ₽)
insert into public.clients (id, gym_id, full_name, phone, source, created_at) values
  ('00000000-0000-0000-0000-0000000000b2', tests.id('gym_b'), 'Б2', '+79160000102', 'сайт', now() - interval '60 days'),
  ('00000000-0000-0000-0000-0000000000b3', tests.id('gym_b'), 'Б3', '+79160000103', 'сайт', now() - interval '60 days');
insert into public.memberships (gym_id, client_id, plan_name, kind, starts_on, ends_on, status, price_paid, created_at) values
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b2', 'Безлимит', 'unlimited', tests.today() - 45, tests.today() - 16, 'expired', 500000, now() - interval '45 days'),
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b3', 'Безлимит', 'unlimited', tests.today() - 39, tests.today() - 10, 'expired', 500000, now() - interval '39 days'),
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b3', 'Безлимит', 'unlimited', tests.today() - 5, tests.today() + 24, 'active', 400000, now() - interval '5 days');
insert into public.payments (gym_id, client_id, amount, method, status, paid_at) values
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b3', 400000, 'card', 'succeeded', now() - interval '5 days'),
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b3', 500000, 'card', 'succeeded', now() - interval '39 days');

select tests.login(tests.id('owner_b'));
do $$
declare
  k jsonb := public.dashboard_kpi(tests.id('gym_b'), tests.today() - 20, tests.today());
  c jsonb := k -> 'current';
begin
  perform tests.assert((c ->> 'revenue')::bigint = 900000, 'выручка 9 000 ₽: ' || c::text);
  perform tests.assert((c ->> 'active_clients')::int = 2, 'активных 2 (b1, b3)');
  perform tests.assert((c ->> 'renewal_ended')::int = 2 and (c ->> 'renewal_renewed')::int = 1, 'закончилось 2, продлён 1');
  perform tests.assert((c ->> 'renewal_rate')::numeric = 50.0, 'продление 50%');
  perform tests.assert((c ->> 'churn')::int = 1, 'отток 1 (b2)');
  perform tests.assert((c ->> 'new_clients')::int = 1, 'новый клиент 1 (b1)');
  perform tests.assert((k -> 'previous' ->> 'revenue')::bigint = 500000, 'выручка прошлого периода');
  perform tests.assert((k -> 'occupancy' ->> 'now')::int = 1, 'в зале сейчас 1 человек');
end $$;
reset role;

-- ===========================================================================
-- 5.8 «В зоне риска»
-- ===========================================================================
insert into public.clients (id, gym_id, full_name, phone, last_visit_at) values
  ('00000000-0000-0000-0000-0000000000b4', tests.id('gym_b'), 'Пропал', '+79160000104', now() - interval '12 days'),
  ('00000000-0000-0000-0000-0000000000b5', tests.id('gym_b'), 'Заканчивается', '+79160000105', now() - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000b6', tests.id('gym_b'), 'Не продлил', '+79160000106', now() - interval '6 days'),
  ('00000000-0000-0000-0000-0000000000b7', tests.id('gym_b'), 'Реже', '+79160000107', now() - interval '3 days');
insert into public.memberships (gym_id, client_id, plan_name, kind, starts_on, ends_on, status) values
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b4', 'Безлимит', 'unlimited', tests.today() - 20, tests.today() + 20, 'active'),
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b5', 'Безлимит', 'unlimited', tests.today() - 27, tests.today() + 3, 'active'),
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b6', 'Безлимит', 'unlimited', tests.today() - 35, tests.today() - 5, 'expired'),
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b7', 'Безлимит', 'unlimited', tests.today() - 60, tests.today() + 20, 'active');
insert into public.visits (gym_id, client_id, checked_in_at, checked_out_at, method)
select tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b7', now() - (d || ' days')::interval, now() - (d || ' days')::interval + interval '1 hour', 'manual'
  from unnest(array[3, 16, 18, 21, 25, 28, 32, 35, 40, 45]) d;
insert into public.visits (gym_id, client_id, checked_in_at, checked_out_at, method) values
  (tests.id('gym_b'), '00000000-0000-0000-0000-0000000000b4', now() - interval '12 days', now() - interval '12 days' + interval '1 hour', 'manual');

select tests.login(tests.id('owner_b'));
do $$
declare
  r record;
begin
  perform tests.assert((select reason from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b4') = 'gone', 'Пропал');
  perform tests.assert((select days_absent from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b4') = 12, '12 дней без визитов');
  perform tests.assert((select reason from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b5') = 'expiring', 'Заканчивается');
  perform tests.assert((select reason from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b6') = 'not_renewed', 'Не продлил');
  perform tests.assert((select reason from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b7') = 'declining',
                       'Стал ходить реже: ' || coalesce((select reason_text from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b7'), 'нет в списке'));
  perform tests.assert(not exists (select 1 from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b2'), 'b2 — больше 14 дней, не в списке');
  perform tests.assert(not exists (select 1 from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b3'), 'b3 продлил');
  -- сортировка по срочности: «не продлил» выше «пропал»
  perform tests.assert((select client_id from public.v_client_risk where gym_id = tests.id('gym_b') order by urgency desc limit 1)
                       = '00000000-0000-0000-0000-0000000000b6', 'сортировка по срочности');
  -- связались → пришёл → исчез из списка «Пропал», счётчик «вернулись» растёт
  perform public.mark_contacted('00000000-0000-0000-0000-0000000000b4', 'gone', 'whatsapp');
  perform public.checkin_manual('00000000-0000-0000-0000-0000000000b4');
  perform tests.assert(not exists (select 1 from public.v_client_risk where client_id = '00000000-0000-0000-0000-0000000000b4'),
                       'пришедший клиент исчезает из списка');
  perform tests.assert((public.risk_returned_stats(tests.id('gym_b')) ->> 'returned')::int = 1, 'счётчик «вернулись»');
end $$;
reset role;

-- ===========================================================================
-- Ночное задание (FR-3.5)
-- ===========================================================================
update public.memberships set status = 'active' where client_id = '00000000-0000-0000-0000-0000000000b6';
select tests.assert((public.run_maintenance() ->> 'expired')::int >= 1, 'истёкшие → expired');
select tests.assert((select status from public.memberships where client_id = '00000000-0000-0000-0000-0000000000b6') = 'expired', 'b6 expired');
select tests.assert((select status from public.memberships where client_id = tests.id('client_a4')) = 'frozen', 'заморозка сохраняется');

-- Очередь уведомлений: воркер забирает только готовые к отправке, без двойной выдачи
do $$
declare
  n1 int;
  n2 int;
begin
  update public.notifications_outbox set send_after = now() - interval '1 minute' where status = 'queued';
  select count(*) into n1 from public.claim_notifications(1000);
  select count(*) into n2 from public.claim_notifications(1000);
  perform tests.assert(n1 > 0 and n2 = 0, format('выдано %s, повторно %s', n1, n2));
  perform public.complete_notification((select id from public.notifications_outbox where status = 'queued' limit 1), 'failed', 'push', 'timeout');
  perform tests.assert(exists (select 1 from public.notifications_outbox where last_error = 'timeout' and status = 'queued'),
                       'неудачная отправка вернётся в очередь');
end $$;

select 'business rules: OK' as result;
rollback;
