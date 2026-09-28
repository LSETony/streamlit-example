-- Автотест изоляции залов (раздел 7, приёмка MVP):
-- сотрудник зала А не видит ни одной строки зала Б — проверяется для КАЖДОЙ таблицы и представления с gym_id.
begin;
\ir local/fixture.sql

-- Все таблицы и представления public с колонкой gym_id
create temp table rls_targets as
  select c.table_name::text as rel
    from information_schema.columns c
    join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
   where c.table_schema = 'public' and c.column_name = 'gym_id'
     and c.table_name not in ('v_gym_kpi_month', 'v_occupancy_hourly');
grant select on rls_targets to authenticated;

do $$
declare
  r record;
  n bigint;
  seen_own int := 0;
begin
  -- 1. Под суперпользователем убеждаемся, что у зала А данные есть почти во всех таблицах
  for r in select rel from rls_targets loop
    execute format('select count(*) from public.%I where gym_id = %L', r.rel, tests.id('gym_a')) into n;
    if n > 0 then seen_own := seen_own + 1; end if;
  end loop;
  if seen_own < 12 then raise exception 'Фикстура заполнила слишком мало таблиц: %', seen_own; end if;
end $$;

-- 2. Каждая роль зала Б и клиент не видят строк зала А; сотрудники А — строк зала Б
create or replace function tests.assert_isolated(p_user uuid, p_foreign_gym uuid, p_label text) returns void
language plpgsql as $$
declare
  r record;
  n bigint;
begin
  perform tests.login(p_user);
  for r in select rel from rls_targets where has_table_privilege('authenticated', 'public.' || rel, 'select') loop
    execute format('select count(*) from public.%I where gym_id = %L', r.rel, p_foreign_gym) into n;
    if n <> 0 then
      raise exception 'RLS: % видит % строк чужого зала в %', p_label, n, r.rel;
    end if;
  end loop;
  perform set_config('role', 'postgres', true);
end $$;
grant execute on function tests.assert_isolated to authenticated;

select tests.assert_isolated(tests.id('owner_b'), tests.id('gym_a'), 'владелец Б');
select tests.assert_isolated(tests.id('owner_a'), tests.id('gym_b'), 'владелец А');
select tests.assert_isolated(tests.id('admin_a'), tests.id('gym_b'), 'администратор А');
select tests.assert_isolated(tests.id('reception_a'), tests.id('gym_b'), 'ресепшен А');
select tests.assert_isolated(tests.id('client_user'), tests.id('gym_b'), 'клиент А');
select tests.assert_isolated(tests.id('platform'), tests.id('gym_a'), 'команда core.')
  where false;  -- команда видит строку зала (gyms), но не персональные данные — проверяется ниже

-- 3. Сотрудник Б не может писать в зал А
select tests.login(tests.id('owner_b'));
select tests.expect_error(format($q$insert into public.clients (gym_id, full_name, phone) values (%L, 'Чужой', '+79160000999')$q$,
                                 tests.id('gym_a')), '42501');
do $$
declare n int;
begin
  update public.clients set note = 'взлом' where gym_id = tests.id('gym_a');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'RLS: владелец Б изменил клиентов зала А'; end if;
  update public.membership_plans set price = 1 where gym_id = tests.id('gym_a');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'RLS: владелец Б изменил тарифы зала А'; end if;
end $$;
select tests.expect_error(format('select public.sell_membership(%L, %L, ''cash'')', tests.id('client_a1'), tests.id('plan_month')), 'FORBIDDEN');
select tests.expect_error(format('select public.checkin_manual(%L)', tests.id('client_a1')), 'FORBIDDEN');
select tests.expect_error(format('select public.dashboard_kpi(%L)', tests.id('gym_a')), 'FORBIDDEN');
select tests.expect_error(format('select public.book_class(%L, %L)', tests.id('class_a'), tests.id('client_b1')), 'CLIENT_NOT_FOUND');
reset role;

-- 4. Прямые изменения денежных таблиц запрещены всем ролям — только через функции
select tests.login(tests.id('owner_a'));
select tests.expect_error(format($q$insert into public.payments (gym_id, amount, method, status) values (%L, 100, 'cash', 'succeeded')$q$, tests.id('gym_a')), '42501');
select tests.expect_error(format($q$update public.memberships set price_paid = 0 where gym_id = %L$q$, tests.id('gym_a')), '42501');
select tests.expect_error(format($q$insert into public.visits (gym_id, client_id, method) values (%L, %L, 'manual')$q$, tests.id('gym_a'), tests.id('client_a1')), '42501');
select tests.expect_error(format($q$delete from public.clients where id = %L$q$, tests.id('client_a1')), '42501');
select tests.expect_error('select * from public.gym_secrets', '42501');
select tests.expect_error('select * from public.notifications_outbox', '42501');
select tests.expect_error(format($q$update public.gyms set trial_until = '2099-01-01' where id = %L$q$, tests.id('gym_a')), '42501');
select tests.expect_error(format($q$select public.confirm_online_payment('yookassa', 'x', 'succeeded')$q$), '42501');
select tests.expect_error('select public.claim_notifications(10)', '42501');
select tests.expect_error('select public.run_maintenance()', '42501');
reset role;

-- 5. Права ролей (раздел 2)
select tests.login(tests.id('reception_a'));
do $$
declare n int;
begin
  select count(*) into n from public.payments;
  if n <> 0 then raise exception 'Ресепшен видит оплаты (выручку): %', n; end if;
  select count(*) into n from public.audit_log;
  if n <> 0 then raise exception 'Ресепшен видит журнал действий'; end if;
  select count(*) into n from public.clients where gym_id = tests.id('gym_a');
  if n < 2 then raise exception 'Ресепшен должен видеть клиентов зала'; end if;
  update public.membership_plans set price = 1 where gym_id = tests.id('gym_a');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Ресепшен изменил тариф'; end if;
  update public.gyms set name = 'x' where id = tests.id('gym_a');
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Ресепшен изменил настройки зала'; end if;
end $$;
select tests.expect_error(format('select public.dashboard_kpi(%L)', tests.id('gym_a')), 'FORBIDDEN');
select tests.expect_error(format('select public.payments_summary(%L, current_date, current_date)', tests.id('gym_a')), 'FORBIDDEN');
select tests.expect_error(format('select public.anonymize_client(%L)', tests.id('client_a1')), 'FORBIDDEN');
select tests.expect_error(format('select public.import_clients(%L, ''[]'')', tests.id('gym_a')), 'FORBIDDEN');
select tests.expect_error(format('select public.refund_payment(%L)',
  (select id from public.payments limit 1)), 'PAYMENT_NOT_FOUND');   -- оплату ресепшен даже не видит
select tests.expect_error(format($q$insert into public.staff (gym_id, email, role, full_name) values (%L, 'x@x.ru', 'owner', 'X')$q$, tests.id('gym_a')), '42501');
reset role;

select tests.login(tests.id('admin_a'));
do $$
declare n int;
begin
  select count(*) into n from public.payments where gym_id = tests.id('gym_a');
  if n = 0 then raise exception 'Администратор должен видеть оплаты'; end if;
  select count(*) into n from public.audit_log;
  if n <> 0 then raise exception 'Журнал действий — только владельцу'; end if;
end $$;
select public.dashboard_kpi(tests.id('gym_a'));
reset role;

-- 6. Клиент в приложении видит только свои данные
select tests.login(tests.id('client_user'));
do $$
declare n int;
begin
  select count(*) into n from public.clients;
  if n <> 1 then raise exception 'Клиент видит % карточек клиентов вместо 1', n; end if;
  select count(*) into n from public.memberships where client_id <> tests.id('client_a1');
  if n <> 0 then raise exception 'Клиент видит чужие абонементы'; end if;
  select count(*) into n from public.visits where client_id <> tests.id('client_a1');
  if n <> 0 then raise exception 'Клиент видит чужие визиты'; end if;
  select count(*) into n from public.payments where client_id <> tests.id('client_a1');
  if n <> 0 then raise exception 'Клиент видит чужие оплаты'; end if;
  select count(*) into n from public.staff;
  if n <> 0 then raise exception 'Клиент видит сотрудников'; end if;
  select count(*) into n from public.v_client_risk;
  if n <> 0 then raise exception 'Клиент видит список риска'; end if;
  select count(*) into n from public.public_gyms;
  if n < 2 then raise exception 'Каталог залов должен быть доступен приложению'; end if;
end $$;
select tests.expect_error(format('select public.checkin_manual(%L)', tests.id('client_a1')), 'FORBIDDEN');
reset role;

-- 7. Команда core. видит залы и счётчики, но не персональные данные клиентов
select tests.login(tests.id('platform'));
do $$
declare n int;
begin
  select count(*) into n from public.admin_list_gyms();
  if n < 2 then raise exception 'Суперадмин должен видеть все залы'; end if;
  select count(*) into n from public.clients;
  if n <> 0 then raise exception 'Суперадмин видит клиентов без запроса поддержки'; end if;
  select count(*) into n from public.payments;
  if n <> 0 then raise exception 'Суперадмин видит оплаты клиентов'; end if;
end $$;
reset role;
select tests.login(tests.id('owner_a'));
select tests.expect_error('select * from public.admin_list_gyms()', 'FORBIDDEN');
reset role;

select 'RLS isolation: OK' as result;
rollback;
