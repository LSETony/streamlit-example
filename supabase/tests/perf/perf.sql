-- Нагрузочная проверка (раздел 7): 5 000 клиентов, 2 года истории.
-- Дашборд — до 2 с, проверка QR — до 1 с, список риска и клиентов — до 2 с.
-- Запуск: psql -d <база с миграциями> -f supabase/tests/perf/perf.sql
\timing off
\set ON_ERROR_STOP 1
set client_min_messages = warning;
begin;
insert into auth.users (id, email, phone) values
  ('00000000-0000-0000-0000-00000000e001', 'perf-owner@test.ru', null),
  ('00000000-0000-0000-0000-00000000e002', null, '79169999999');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000e001';
set local role authenticated;
select set_config('perf.gym', public.create_gym('Нагрузка', 'Владелец')::text, true);
reset role;

insert into public.membership_plans (gym_id, name, kind, price, duration_days, freeze_days_max)
values (current_setting('perf.gym')::uuid, 'Месяц', 'period', 300000, 30, 7);

-- 5 000 клиентов
insert into public.clients (gym_id, full_name, phone, source, created_at)
select current_setting('perf.gym')::uuid, 'Клиент ' || i, '+7916' || lpad(i::text, 7, '0'),
       (array['instagram','сайт','рекомендация','вывеска','импорт'])[1 + i % 5],
       now() - ((i % 730) || ' days')::interval
  from generate_series(1, 5000) i;
update public.clients set phone = '+79169999999' where full_name = 'Клиент 1';

-- 2 года помесячных абонементов: у каждого клиента серия с пропусками (≈ 60 000 абонементов)
insert into public.memberships (gym_id, client_id, plan_name, kind, starts_on, ends_on, status, price_paid, created_at)
select c.gym_id, c.id, 'Месяц', 'period', d, d + 29,
       case when d + 29 < current_date then 'expired' else 'active' end::public.membership_status,
       300000, d::timestamp at time zone 'Europe/Moscow'
  from public.clients c
 cross join lateral (select g::date as d from generate_series(current_date - 720 + (abs(hashtext(c.id::text)) % 30),
                                                             current_date, interval '30 days') g) s
 where c.gym_id = current_setting('perf.gym')::uuid and (abs(hashtext(c.id::text || d::text)) % 10) < 7;

insert into public.payments (gym_id, client_id, membership_id, amount, method, status, paid_at, created_at)
select gym_id, client_id, id, price_paid, (array['cash','card','online'])[1 + abs(hashtext(id::text)) % 3]::public.payment_method,
       'succeeded', created_at, created_at
  from public.memberships where gym_id = current_setting('perf.gym')::uuid;

-- визиты: ~8 в месяц на действующий абонемент (≈ 350 000 визитов)
insert into public.visits (gym_id, client_id, membership_id, checked_in_at, checked_out_at, method)
select m.gym_id, m.client_id, m.id, ts, ts + interval '90 minutes', 'manual'
  from public.memberships m
 cross join lateral (
   select (m.starts_on + (k * 4 + abs(hashtext(m.id::text || k)) % 3))::timestamp at time zone 'Europe/Moscow'
          + make_interval(hours => 8 + abs(hashtext(m.id::text || k || 'h')) % 13) as ts
     from generate_series(0, 7) k) v
 where m.gym_id = current_setting('perf.gym')::uuid and v.ts < now() - interval '3 hours';
update public.clients c set last_visit_at = v.mx
  from (select client_id, max(checked_in_at) mx from public.visits group by client_id) v
 where v.client_id = c.id;

insert into public.client_devices (id, user_id, platform, qr_secret)
values ('00000000-0000-0000-0000-00000000d001', '00000000-0000-0000-0000-00000000e002', 'ios', repeat('ab', 32));
update public.clients set user_id = '00000000-0000-0000-0000-00000000e002' where phone = '+79169999999';
commit;
analyze;

select 'clients' as what, count(*) from public.clients
union all select 'memberships', count(*) from public.memberships
union all select 'payments', count(*) from public.payments
union all select 'visits', count(*) from public.visits;

-- Замеры от имени владельца
create or replace function pg_temp.bench(p_label text, p_sql text, p_limit_ms int) returns text language plpgsql as $$
declare
  t0 timestamptz;
  ms numeric;
begin
  t0 := clock_timestamp();
  execute p_sql;
  ms := round(extract(epoch from clock_timestamp() - t0) * 1000);
  if ms > p_limit_ms then
    raise exception 'МЕДЛЕННО: % — % мс (лимит % мс)', p_label, ms, p_limit_ms;
  end if;
  return format('%s: %s мс (лимит %s)', p_label, ms, p_limit_ms);
end $$;

set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000e001';
set role authenticated;
select pg_temp.bench('Дашборд (6 метрик + загруженность)',
  format('select public.dashboard_kpi(%L)', (select id from public.gyms where name = 'Нагрузка')), 2000);
select pg_temp.bench('Список «в зоне риска»', 'select count(*) from public.v_client_risk', 2000);
select pg_temp.bench('Список клиентов (первая страница)',
  'select * from public.v_clients order by full_name limit 50', 2000);
select pg_temp.bench('Поиск клиента по телефону',
  $q$select * from public.v_clients where phone like '%0004242%' limit 20$q$, 2000);
select pg_temp.bench('Журнал оплат за месяц',
  format('select public.payments_summary(%L, current_date - 30, current_date)', (select id from public.gyms where name = 'Нагрузка')), 2000);
select pg_temp.bench('Проверка QR',
  format($q$select public.checkin_qr(%L, 'CORE1:00000000-0000-0000-0000-00000000d001:' || floor(extract(epoch from now()) / 30)::bigint || ':' ||
     left(encode(extensions.hmac(convert_to('CORE1:00000000-0000-0000-0000-00000000d001:' || floor(extract(epoch from now()) / 30)::bigint, 'UTF8'),
     decode(repeat('ab', 32), 'hex'), 'sha256'), 'hex'), 32))$q$, (select id from public.gyms where name = 'Нагрузка')), 1000);
reset role;
