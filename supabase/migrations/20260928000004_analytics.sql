-- core. MVP — аналитика: дашборд (5.7), «в зоне риска» (5.8), загруженность, списки.
-- Представления создаются с security_invoker, поэтому к ним применяются политики RLS вызывающего.

-- ---------------------------------------------------------------------------
-- «В зоне риска» (5.8). Список живой: пересчитывается при каждом запросе,
-- то есть сразу после визита или продажи, и ночью ничего пересчитывать не нужно.
-- ---------------------------------------------------------------------------
create or replace view public.v_client_risk with (security_invoker = true) as
with base as (
  select c.id as client_id, c.gym_id, c.full_name, c.phone, c.user_id is not null as in_app,
         c.consent_marketing_at is not null as marketing_ok, c.last_visit_at, c.tags,
         (now() at time zone g.timezone)::date as today,
         (c.last_visit_at at time zone g.timezone)::date as last_visit_on,
         coalesce((g.settings -> 'risk' ->> 'gone_days')::int, 10) as gone_days,
         coalesce((g.settings -> 'risk' ->> 'expiring_days')::int, 7) as expiring_days,
         coalesce((g.settings -> 'risk' ->> 'declining_ratio')::numeric, 0.5) as declining_ratio,
         coalesce((g.settings -> 'risk' ->> 'not_renewed_days')::int, 14) as not_renewed_days
    from public.clients c
    join public.gyms g on g.id = c.gym_id
   where c.deleted_at is null
),
facts as (
  select b.*,
         cur.id as membership_id, cur.starts_on as cur_starts_on, cur.ends_on as cur_ends_on,
         coalesce(cur.frozen, false) as frozen,
         exists (select 1 from public.memberships n
                  where n.client_id = b.client_id and n.status in ('active', 'frozen')
                    and n.starts_on > greatest(b.today, coalesce(cur.ends_on, b.today))) as has_next,
         (select max(m.ends_on) from public.memberships m
           where m.client_id = b.client_id and m.status in ('active', 'frozen', 'expired')) as last_ends_on,
         coalesce(vs.recent, 0) as visits_recent,
         coalesce(vs.prev, 0) as visits_prev
    from base b
    left join lateral (
      select m.id, m.starts_on, m.ends_on,
             exists (select 1 from public.freezes f
                      where f.membership_id = m.id and b.today between f.from_date and f.to_date) as frozen
        from public.memberships m
       where m.client_id = b.client_id and m.status in ('active', 'frozen')
         and b.today between m.starts_on and m.ends_on
       order by m.ends_on desc limit 1
    ) cur on true
    left join lateral (
      select count(*) filter (where v.checked_in_at >= now() - interval '14 days') as recent,
             count(*) filter (where v.checked_in_at < now() - interval '14 days') as prev
        from public.visits v
       where v.client_id = b.client_id and v.checked_in_at >= now() - interval '56 days'
    ) vs on true
),
flags as (
  select f.*,
         f.today - greatest(f.last_visit_on, f.cur_starts_on) as days_absent,
         f.cur_ends_on - f.today as days_left,
         f.today - f.last_ends_on as days_since_end,
         -- Пропал: активный абонемент и нет визитов N+ дней
         (f.membership_id is not null and not f.frozen
          and f.today - greatest(f.last_visit_on, f.cur_starts_on) >= f.gone_days) as is_gone,
         -- Заканчивается: истекает через N дней или меньше, продления нет
         (f.membership_id is not null and not f.has_next
          and f.cur_ends_on - f.today between 0 and f.expiring_days) as is_expiring,
         -- Стал ходить реже: за 2 недели вдвое меньше, чем в среднем за 2 недели в 6 недель до этого
         (f.membership_id is not null and not f.frozen and f.visits_prev >= 3
          and f.visits_recent < f.declining_ratio * (f.visits_prev / 3.0)) as is_declining,
         -- Не продлил: абонемент закончился менее N дней назад
         (f.membership_id is null and not f.has_next and f.last_ends_on is not null
          and f.today - f.last_ends_on between 1 and f.not_renewed_days) as is_not_renewed
    from facts f
)
select fl.gym_id, fl.client_id, fl.full_name, fl.phone, fl.in_app, fl.marketing_ok, fl.tags,
       fl.last_visit_at, fl.membership_id, fl.cur_ends_on as membership_ends_on,
       fl.days_absent, fl.days_left, fl.days_since_end, fl.visits_recent, fl.visits_prev,
       case when fl.is_not_renewed then 'not_renewed'
            when fl.is_expiring then 'expiring'
            when fl.is_gone then 'gone'
            else 'declining' end as reason,
       array_remove(array[
         case when fl.is_not_renewed then 'not_renewed' end,
         case when fl.is_expiring then 'expiring' end,
         case when fl.is_gone then 'gone' end,
         case when fl.is_declining then 'declining' end], null) as reasons,
       case when fl.is_not_renewed then 'Не продлил: абонемент закончился ' || fl.days_since_end || ' дн. назад'
            when fl.is_expiring then case when fl.days_left = 0 then 'Абонемент заканчивается сегодня'
                                          else 'Абонемент заканчивается через ' || fl.days_left || ' дн.' end
            when fl.is_gone then 'Пропал: не приходит ' || fl.days_absent || ' дн.'
            else 'Стал ходить реже: ' || fl.visits_recent || ' виз. за 2 нед. вместо ~' ||
                 round(fl.visits_prev / 3.0, 1) end as reason_text,
       -- срочность: сначала те, кого вот-вот потеряем
       case when fl.is_not_renewed then 3000 + fl.days_since_end * 10
            when fl.is_expiring then 2000 + (fl.expiring_days - fl.days_left) * 10
            when fl.is_gone then 1000 + fl.days_absent
            else 500 + (fl.visits_prev / 3.0 - fl.visits_recent)::int end as urgency,
       rc.contacted_at, rc.channel as contact_channel
  from flags fl
  left join lateral (
    select r.contacted_at, r.channel from public.risk_contacts r
     where r.client_id = fl.client_id and r.contacted_at >= now() - interval '14 days'
     order by r.contacted_at desc limit 1
  ) rc on true
 where fl.is_gone or fl.is_expiring or fl.is_declining or fl.is_not_renewed;

-- ---------------------------------------------------------------------------
-- Список клиентов с состоянием абонемента (FR-2.1)
-- ---------------------------------------------------------------------------
create or replace view public.v_clients with (security_invoker = true) as
select c.id, c.gym_id, c.full_name, c.phone, c.email, c.source, c.tags, c.user_id is not null as in_app,
       c.last_visit_at, c.created_at, c.photo_url,
       ms.id as membership_id, ms.plan_name, ms.ends_on as membership_ends_on, ms.visits_left,
       case
         when ms.id is null and fut.id is not null then 'future'
         when ms.id is null and c.has_any then 'expired'
         when ms.id is null then 'none'
         when ms.frozen then 'frozen'
         else 'active'
       end as membership_state
  from (select c0.*, exists (select 1 from public.memberships m0 where m0.client_id = c0.id
                               and m0.status in ('active', 'frozen', 'expired')) as has_any,
               (now() at time zone g.timezone)::date as today
          from public.clients c0 join public.gyms g on g.id = c0.gym_id
         where c0.deleted_at is null) c
  left join lateral (
    select m.id, m.plan_name, m.ends_on, m.visits_left,
           exists (select 1 from public.freezes f where f.membership_id = m.id
                     and c.today between f.from_date and f.to_date) as frozen
      from public.memberships m
     where m.client_id = c.id and m.status in ('active', 'frozen') and c.today between m.starts_on and m.ends_on
     order by m.ends_on desc limit 1
  ) ms on true
  left join lateral (
    select m.id from public.memberships m
     where m.client_id = c.id and m.status in ('active', 'frozen') and m.starts_on > c.today limit 1
  ) fut on true;

-- ---------------------------------------------------------------------------
-- «Кто сейчас в зале» (FR-4.5): открытые визиты с учётом автоматического выхода
-- ---------------------------------------------------------------------------
create or replace view public.v_in_gym with (security_invoker = true) as
select v.id as visit_id, v.gym_id, v.client_id, c.full_name, c.photo_url, v.checked_in_at, v.method,
       m.plan_name, m.ends_on as membership_ends_on, m.visits_left
  from public.visits v
  join public.clients c on c.id = v.client_id
  join public.gyms g on g.id = v.gym_id
  left join public.memberships m on m.id = v.membership_id
 where v.checked_out_at is null
   and v.checked_in_at > now() - make_interval(hours => coalesce((g.settings ->> 'auto_checkout_hours')::int, 3));

-- ---------------------------------------------------------------------------
-- Загруженность: сейчас и тепловая карта «день недели × час» за 4 недели. Без персональных данных.
-- ---------------------------------------------------------------------------
create or replace function public.gym_occupancy(p_gym uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  g public.gyms;
  v_hours int;
  v_now int;
  v_capacity int;
  v_heat jsonb;
  v_today_forecast jsonb;
begin
  select * into g from public.gyms where id = p_gym;
  if g.id is null then perform private.fail('GYM_NOT_FOUND', 'Зал не найден'); end if;
  v_hours := coalesce((g.settings ->> 'auto_checkout_hours')::int, 3);
  v_capacity := coalesce(nullif((g.settings ->> 'capacity')::int, 0),
                         (select sum(capacity)::int from public.zones where gym_id = p_gym), 0);

  select count(*) into v_now from public.visits
   where gym_id = p_gym and checked_out_at is null and checked_in_at > now() - make_interval(hours => v_hours);

  -- каждый визит раскладываем по часам, которые он покрывает, и считаем людей в каждом часе
  with v as (
    select checked_in_at s,
           coalesce(checked_out_at, least(checked_in_at + make_interval(hours => v_hours), now())) e
      from public.visits
     where gym_id = p_gym and checked_in_at >= now() - interval '28 days' - make_interval(hours => v_hours)
  ), buckets as (
    select h, count(*) as people
      from v cross join lateral generate_series(date_trunc('hour', v.s), v.e - interval '1 microsecond', interval '1 hour') h
     where h >= date_trunc('hour', now() - interval '28 days') and h < date_trunc('hour', now())
     group by h
  ), per_hour as (
    select hs.h, coalesce(b.people, 0) as people
      from generate_series(date_trunc('hour', now() - interval '28 days'),
                           date_trunc('hour', now()) - interval '1 hour', interval '1 hour') hs(h)
      left join buckets b on b.h = hs.h
  ), agg as (
    select extract(isodow from h at time zone g.timezone)::int as dow,
           extract(hour from h at time zone g.timezone)::int as hour,
           round(avg(people)::numeric, 1) as avg_people
      from per_hour group by 1, 2
  )
  select coalesce(jsonb_agg(jsonb_build_object('dow', dow, 'hour', hour, 'avg', avg_people) order by dow, hour), '[]')
    into v_heat from agg;

  select coalesce(jsonb_agg(jsonb_build_object('hour', (x ->> 'hour')::int, 'avg', (x ->> 'avg')::numeric)
                            order by (x ->> 'hour')::int), '[]')
    into v_today_forecast
    from jsonb_array_elements(v_heat) x
   where (x ->> 'dow')::int = extract(isodow from now() at time zone g.timezone)::int;

  return jsonb_build_object('now', v_now, 'capacity', v_capacity,
                            'load_pct', case when v_capacity > 0 then round(100.0 * v_now / v_capacity) end,
                            'heatmap', v_heat, 'today_forecast', v_today_forecast,
                            'timezone', g.timezone, 'generated_at', now());
end $$;

-- ---------------------------------------------------------------------------
-- Дашборд (5.7). Формулы зафиксированы в ТЗ — считаем ровно так.
-- ---------------------------------------------------------------------------
-- Абонемент m «продлён», если за ним куплен другой абонемент, заканчивающийся позже,
-- не позднее 14 дней после окончания m.
create or replace function private.is_renewed(m public.memberships, p_tz text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.memberships n
     where n.client_id = m.client_id and n.id <> m.id
       and n.status not in ('cancelled', 'pending')
       and n.ends_on > m.ends_on
       and case when n.imported then n.starts_on <= m.ends_on + 15
                else (n.created_at at time zone p_tz)::date <= m.ends_on + 14 end
  )
$$;

create or replace function private.kpi_period(p_gym uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text;
  v_today date;
  v_end date;
  v_ts_from timestamptz;
  v_ts_to timestamptz;
  v_revenue bigint;
  v_active int;
  v_ended int;
  v_renewed int;
  v_churn int;
  v_new int;
  v_by_source jsonb;
begin
  select timezone into v_tz from public.gyms where id = p_gym;
  v_today := (now() at time zone v_tz)::date;
  v_end := least(p_to, v_today);
  v_ts_from := p_from::timestamp at time zone v_tz;
  v_ts_to := (p_to + 1)::timestamp at time zone v_tz;

  -- Выручка: успешные оплаты минус возвраты
  select coalesce(sum(case when refund_of_id is null then amount else -amount end), 0) into v_revenue
    from public.payments
   where gym_id = p_gym and paid_at >= v_ts_from and paid_at < v_ts_to
     and ((refund_of_id is null and status in ('succeeded', 'refunded'))
          or (refund_of_id is not null and status = 'refunded'));

  -- Активные клиенты: абонемент active или frozen на конец периода
  select count(distinct client_id) into v_active
    from public.memberships
   where gym_id = p_gym and status not in ('cancelled', 'pending')
     and starts_on <= v_end and ends_on >= v_end;

  -- Процент продления: из закончившихся в периоде — доля продлённых в течение 14 дней
  select count(*), count(*) filter (where private.is_renewed(m, v_tz))
    into v_ended, v_renewed
    from public.memberships m
   where m.gym_id = p_gym and m.status not in ('cancelled', 'pending')
     and m.ends_on between p_from and least(p_to, v_today - 1);

  -- Отток: клиенты, чей абонемент закончился и не продлён 14 дней (событие — 14-й день)
  select count(distinct m.client_id) into v_churn
    from public.memberships m
   where m.gym_id = p_gym and m.status not in ('cancelled', 'pending')
     and m.ends_on + 14 between p_from and least(p_to, v_today)
     and not private.is_renewed(m, v_tz);

  -- Новые клиенты: первый абонемент куплен в периоде; разбивка по источнику
  with firsts as (
    select m.client_id,
           min(case when m.imported then m.starts_on else (m.created_at at time zone v_tz)::date end) as first_on
      from public.memberships m
     where m.gym_id = p_gym and m.status not in ('cancelled', 'pending')
     group by m.client_id
  ), fresh as (
    select coalesce(nullif(c.source, ''), 'не указан') as source
      from firsts f join public.clients c on c.id = f.client_id
     where f.first_on between p_from and p_to
  )
  select count(*),
         coalesce((select jsonb_agg(jsonb_build_object('source', source, 'count', n) order by n desc)
                     from (select source, count(*) n from fresh group by source) s), '[]')
    into v_new, v_by_source
    from fresh;

  return jsonb_build_object(
    'revenue', v_revenue,
    'active_clients', v_active,
    'renewal_rate', case when v_ended > 0 then round(100.0 * v_renewed / v_ended, 1) end,
    'renewal_ended', v_ended,
    'renewal_renewed', v_renewed,
    'churn', v_churn,
    'new_clients', v_new,
    'new_by_source', v_by_source);
end $$;

create or replace function public.dashboard_kpi(p_gym uuid, p_from date default null, p_to date default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_today date;
  v_from date;
  v_to date;
  v_len int;
  v_prev_from date;
  v_prev_to date;
begin
  perform private.require_staff(p_gym, '{owner,admin}', false);
  v_today := private.gym_today(p_gym);
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);
  if v_to < v_from then perform private.fail('INVALID_DATE', 'Конец периода раньше начала'); end if;
  -- предыдущий период той же длины; для календарного месяца — предыдущий месяц целиком
  if v_from = date_trunc('month', v_from)::date and v_to = (date_trunc('month', v_from) + interval '1 month - 1 day')::date then
    v_prev_from := (v_from - interval '1 month')::date;
    v_prev_to := v_from - 1;
  else
    v_len := v_to - v_from + 1;
    v_prev_to := v_from - 1;
    v_prev_from := v_from - v_len;
  end if;
  return jsonb_build_object(
    'period', jsonb_build_object('from', v_from, 'to', v_to),
    'previous_period', jsonb_build_object('from', v_prev_from, 'to', v_prev_to),
    'current', private.kpi_period(p_gym, v_from, v_to),
    'previous', private.kpi_period(p_gym, v_prev_from, v_prev_to),
    'occupancy', public.gym_occupancy(p_gym));
end $$;

-- 6 метрик по месяцам за последние 24 месяца (для отчётов)
create or replace view public.v_gym_kpi_month with (security_invoker = true) as
select g.id as gym_id, mon::date as month,
       (k ->> 'revenue')::bigint as revenue,
       (k ->> 'active_clients')::int as active_clients,
       (k ->> 'renewal_rate')::numeric as renewal_rate,
       (k ->> 'churn')::int as churn,
       (k ->> 'new_clients')::int as new_clients,
       k -> 'new_by_source' as new_by_source
  from public.gyms g
 cross join lateral generate_series(date_trunc('month', now() at time zone g.timezone) - interval '23 months',
                                    date_trunc('month', now() at time zone g.timezone), interval '1 month') mon
 cross join lateral private.kpi_period(g.id, mon::date, (mon + interval '1 month - 1 day')::date) k
 where private.is_staff(g.id, '{owner,admin}');

-- Средняя загруженность по дням недели и часам за 4 недели
create or replace view public.v_occupancy_hourly with (security_invoker = true) as
select g.id as gym_id, (x ->> 'dow')::int as dow, (x ->> 'hour')::int as hour, (x ->> 'avg')::numeric as avg_people
  from public.gyms g
 cross join lateral jsonb_array_elements(public.gym_occupancy(g.id) -> 'heatmap') x;

-- Итоги журнала оплат за период (FR-6.4)
create or replace function public.payments_summary(p_gym uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text;
  v_res jsonb;
begin
  perform private.require_staff(p_gym, '{owner,admin}', false);
  select timezone into v_tz from public.gyms where id = p_gym;
  select jsonb_build_object(
           'income', coalesce(sum(amount) filter (where refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'refunds', coalesce(sum(amount) filter (where refund_of_id is not null and status = 'refunded'), 0),
           'cash', coalesce(sum(amount) filter (where method = 'cash' and refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'card', coalesce(sum(amount) filter (where method = 'card' and refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'online', coalesce(sum(amount) filter (where method = 'online' and refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'count', count(*) filter (where refund_of_id is null and status in ('succeeded', 'refunded')))
    into v_res
    from public.payments
   where gym_id = p_gym
     and paid_at >= p_from::timestamp at time zone v_tz and paid_at < (p_to + 1)::timestamp at time zone v_tz;
  return v_res || jsonb_build_object('net', (v_res ->> 'income')::bigint - (v_res ->> 'refunds')::bigint);
end $$;

-- Счётчик «вернулись» (FR-8.3)
create or replace function public.risk_returned_stats(p_gym uuid, p_from date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_from timestamptz;
begin
  perform private.require_staff(p_gym, null, false);
  v_from := coalesce(p_from::timestamp at time zone (select timezone from public.gyms where id = p_gym),
                     now() - interval '30 days');
  return (
    select jsonb_build_object('contacted', count(distinct client_id),
                              'returned', count(distinct client_id) filter (where returned_at is not null))
      from public.risk_contacts where gym_id = p_gym and contacted_at >= v_from);
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
revoke execute on function public.confirm_online_payment(text, text, text, text) from authenticated;
revoke execute on function public.attach_provider_payment(uuid, text, text) from authenticated;
revoke execute on function public.confirm_refund(uuid, boolean, text) from authenticated;
revoke execute on function public.run_maintenance() from authenticated;
revoke execute on function public.claim_notifications(int) from authenticated;
revoke execute on function public.complete_notification(uuid, text, text, text) from authenticated;
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated, service_role;
revoke all on public.v_client_risk, public.v_clients, public.v_in_gym, public.v_gym_kpi_month,
              public.v_occupancy_hourly from anon;
grant select on public.v_client_risk, public.v_clients, public.v_in_gym, public.v_gym_kpi_month,
               public.v_occupancy_hourly to authenticated;

-- ---------------------------------------------------------------------------
-- Расписание фоновых заданий (если установлен pg_cron — как в Supabase)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('core-maintenance-nightly', '5 0 * * *', 'select public.run_maintenance()');
    -- автоматический выход и статусы заморозок — ещё и каждые 15 минут
    perform cron.schedule('core-maintenance-15m', '*/15 * * * *', 'select public.run_maintenance()');
  end if;
exception when others then
  raise notice 'pg_cron недоступен: задания нужно запускать внешним планировщиком (%).', sqlerrm;
end $$;
