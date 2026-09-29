-- Демо-данные core.: зал «Атлет» с историей за 10 месяцев — для локальной разработки, показа и пилотов.
-- Входы (пароль у всех demo12345):
--   owner@demo.core      — владелец
--   admin@demo.core      — администратор
--   reception@demo.core  — ресепшен
--   team@demo.core       — команда core. (суперадмин)
-- Приложение: телефон +7 916 000-00-01 (клиент «Иван Петров»), код из SMS в локальной среде — 123456.

select setseed(0.42);

-- ---------------------------------------------------------------------------
-- Пользователи
-- ---------------------------------------------------------------------------
create or replace function pg_temp.demo_user(p_id uuid, p_email text, p_phone text default null) returns uuid
language plpgsql as $$
begin
  insert into auth.users (instance_id, id, aud, role, email, phone, encrypted_password, email_confirmed_at, phone_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email, p_phone,
          extensions.crypt('demo12345', extensions.gen_salt('bf')), now(), case when p_phone is not null then now() end,
          jsonb_build_object('provider', case when p_email is null then 'phone' else 'email' end,
                             'providers', jsonb_build_array(case when p_email is null then 'phone' else 'email' end)),
          '{}', now(), now(), '', '', '', '')
  on conflict (id) do nothing;
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), p_id, p_id::text,
          jsonb_build_object('sub', p_id::text, 'email', p_email, 'phone', p_phone, 'email_verified', true),
          case when p_email is null then 'phone' else 'email' end, now(), now(), now())
  on conflict do nothing;
  return p_id;
end $$;

select pg_temp.demo_user('d0000000-0000-0000-0000-000000000001', 'owner@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000002', 'admin@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000003', 'reception@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000009', 'team@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-0000000000c1', null, '79160000001');
insert into public.platform_admins (user_id) values ('d0000000-0000-0000-0000-000000000009') on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Зал, сотрудники, зоны, тарифы
-- ---------------------------------------------------------------------------
insert into public.gyms (id, name, address, timezone, phone, trial_until, paid_until, onboarded_at, created_at)
values ('d1000000-0000-0000-0000-000000000001', 'Атлет', 'Москва, ул. Спортивная, 12', 'Europe/Moscow', '+74951234567',
        current_date + 14, current_date + 45, now() - interval '300 days', now() - interval '300 days')
on conflict (id) do nothing;

insert into public.staff (gym_id, user_id, email, role, full_name) values
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'owner@demo.core', 'owner', 'Анна Смирнова'),
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'admin@demo.core', 'admin', 'Олег Кузнецов'),
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000003', 'reception@demo.core', 'reception', 'Катя Морозова')
on conflict do nothing;

insert into public.zones (id, gym_id, name, capacity) values
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'Тренажёрный зал', 60),
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'Студия', 20),
  ('d2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', 'Сауна', 6)
on conflict do nothing;

insert into public.membership_plans (id, gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description) values
  ('d3000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'Разовое посещение', 'visits', 60000, 1, 1, 0, true, 'Один визит в течение дня'),
  ('d3000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'Месяц', 'unlimited', 350000, 30, null, 7, true, 'Безлимит на 30 дней'),
  ('d3000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', '8 занятий', 'visits', 280000, 45, 8, 7, true, '8 визитов за 45 дней'),
  ('d3000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000001', '3 месяца', 'unlimited', 900000, 90, null, 14, true, 'Безлимит на 90 дней'),
  ('d3000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000001', 'Утренний', 'period', 250000, 30, null, 7, false, 'До 16:00 по будням')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Клиенты с историей абонементов, оплат и визитов
-- ---------------------------------------------------------------------------
do $$
declare
  g uuid := 'd1000000-0000-0000-0000-000000000001';
  tz text := 'Europe/Moscow';
  today date := (now() at time zone 'Europe/Moscow')::date;
  first_m text[] := array['Иван','Алексей','Дмитрий','Сергей','Андрей','Максим','Артём','Никита','Павел','Егор','Михаил','Роман','Кирилл','Илья','Олег','Денис','Тимур','Глеб'];
  first_f text[] := array['Анна','Мария','Екатерина','Ольга','Наталья','Юлия','Дарья','Алина','Ксения','Полина','Виктория','Елена','София','Вера','Ирина','Татьяна','Алёна','Софья'];
  last_m text[] := array['Иванов','Петров','Сидоров','Смирнов','Кузнецов','Попов','Васильев','Соколов','Михайлов','Новиков','Фёдоров','Морозов','Волков','Алексеев','Лебедев','Семёнов','Егоров','Павлов','Козлов','Степанов','Николаев','Орлов','Андреев','Макаров','Никитин','Захаров'];
  sources text[] := array['Instagram','Instagram','Рекомендация','Рекомендация','Рекомендация','Яндекс Карты','2ГИС','Вывеска','ВКонтакте','Сайт'];
  plans uuid[] := array['d3000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002',
                        'd3000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000005']::uuid[];
  i int;
  c uuid;
  female boolean;
  name text;
  joined date;
  d date;
  pl public.membership_plans;
  pick uuid;
  m uuid;
  loyalty numeric;
  weekly numeric;
  fading boolean;
  ends date;
  v_day date;
  ts timestamptz;
  hour int;
  vleft int;
  method public.payment_method;
  status public.membership_status;
begin
  if exists (select 1 from public.clients where gym_id = g) then return; end if;
  for i in 1..320 loop
    female := random() < 0.52;
    name := case when female
      then last_m[1 + floor(random() * array_length(last_m, 1))::int] || 'а ' || first_f[1 + floor(random() * array_length(first_f, 1))::int]
      else last_m[1 + floor(random() * array_length(last_m, 1))::int] || ' ' || first_m[1 + floor(random() * array_length(first_m, 1))::int] end;
    joined := today - (1 + floor(random() * 290))::int;
    if i = 1 then name := 'Петров Иван'; female := false; joined := today - 200; end if;
    insert into public.clients (gym_id, full_name, phone, email, gender, source, tags, consent_pd_at, consent_pd_text,
                                consent_marketing_at, consent_marketing_text, created_at, user_id)
    values (g, name, '+7916' || lpad(i::text, 7, '0'),
            case when random() < 0.4 then 'client' || i || '@mail.ru' end,
            case when female then 'female' else 'male' end,
            sources[1 + floor(random() * array_length(sources, 1))::int],
            case when random() < 0.15 then array['утро'] when random() < 0.1 then array['vip'] else '{}' end,
            joined::timestamp at time zone tz, 'Согласие получено на ресепшене (демо)',
            case when random() < 0.7 then joined::timestamp at time zone tz end,
            'Согласие на рассылки (демо)', joined::timestamp at time zone tz,
            case when i = 1 then 'd0000000-0000-0000-0000-0000000000c1'::uuid end)
    returning id into c;

    loyalty := 0.55 + random() * 0.4;          -- вероятность продления
    weekly := 1.2 + random() * 2.6;            -- визитов в неделю
    fading := random() < 0.08;                 -- в последние недели стал ходить реже
    d := joined;
    m := null;
    loop
      pick := plans[1 + floor(random() * array_length(plans, 1))::int];
      select * into pl from public.membership_plans where id = pick;
      ends := d + pl.duration_days - 1;
      status := case when ends < today then 'expired' else 'active' end;
      method := (array['card','card','cash','online'])[1 + floor(random() * 4)::int]::public.payment_method;
      insert into public.memberships (gym_id, client_id, plan_id, plan_name, kind, starts_on, ends_on, visits_left,
                                      freeze_days_max, status, price_paid, renewed_from_id, created_at)
      values (g, c, pl.id, pl.name, pl.kind, d, ends, pl.visits_limit, pl.freeze_days_max, status, pl.price, m,
              (d::timestamp + time '10:00' + make_interval(mins => floor(random() * 600)::int)) at time zone tz)
      returning id into m;
      insert into public.payments (gym_id, client_id, membership_id, amount, method, status, provider, paid_at, created_at, description)
      values (g, c, m, pl.price, method, 'succeeded', case when method = 'online' then 'yookassa' end,
              (d::timestamp + time '10:00' + make_interval(mins => floor(random() * 600)::int)) at time zone tz,
              (d::timestamp + time '10:00') at time zone tz, 'Абонемент «' || pl.name || '»');

      -- визиты в период действия
      vleft := coalesce(pl.visits_limit, 1000);
      v_day := d;
      while v_day <= least(ends, today) and vleft > 0 loop
        if random() < ((weekly / 7.0) * (case when fading and v_day > today - 14 then 0.15 else 1 end)) then
          hour := case when random() < 0.3 then 7 + floor(random() * 4)::int
                       when random() < 0.75 then 17 + floor(random() * 5)::int
                       else 11 + floor(random() * 6)::int end;
          if pl.name = 'Утренний' then hour := 7 + floor(random() * 8)::int; end if;
          ts := (v_day::timestamp + make_interval(hours => hour, mins => floor(random() * 60)::int)) at time zone tz;
          if ts < now() - interval '2 hours' then
            insert into public.visits (gym_id, client_id, membership_id, checked_in_at, checked_out_at, method)
            values (g, c, m, ts, ts + make_interval(mins => 50 + floor(random() * 60)::int),
                    case when random() < 0.6 then 'qr' else 'manual' end::public.visit_method);
            vleft := vleft - 1;
          end if;
        end if;
        v_day := v_day + 1;
      end loop;
      if pl.visits_limit is not null then
        update public.memberships set visits_left = greatest(vleft, 0) where id = m;
      end if;

      exit when ends >= today;
      exit when random() > loyalty;                       -- не продлил
      d := ends + 1 + case when random() < 0.25 then floor(random() * 10)::int else 0 end;
      exit when d > today;
    end loop;
  end loop;

  update public.clients cl set last_visit_at = v.mx
    from (select client_id, max(checked_in_at) mx from public.visits where gym_id = g group by client_id) v
   where v.client_id = cl.id;

  -- сейчас в зале
  insert into public.visits (gym_id, client_id, membership_id, checked_in_at, method)
  select g, m2.client_id, m2.id, now() - make_interval(mins => floor(random() * 80)::int), 'qr'
    from public.memberships m2
   where m2.gym_id = g and m2.status = 'active' and m2.starts_on <= today and m2.ends_on >= today and m2.kind <> 'visits'
   order by random() limit 14;

  -- несколько заморозок и контактов из списка риска
  insert into public.freezes (gym_id, membership_id, from_date, to_date, reason)
  select g, m3.id, today - 2, today + 5, 'отпуск'
    from public.memberships m3
   where m3.gym_id = g and m3.status = 'active' and m3.freeze_days_max >= 8 and m3.starts_on < today - 3 and m3.ends_on > today + 10
   order by random() limit 4;
  update public.memberships m4 set ends_on = ends_on + 8, freeze_days_used = 8, status = 'frozen'
   where exists (select 1 from public.freezes f where f.membership_id = m4.id);
end $$;

-- ---------------------------------------------------------------------------
-- Расписание на 4 недели: групповые занятия и записи
-- ---------------------------------------------------------------------------
do $$
declare
  g uuid := 'd1000000-0000-0000-0000-000000000001';
  tz text := 'Europe/Moscow';
  monday date := date_trunc('week', (now() at time zone 'Europe/Moscow'))::date - 7;
  s record;
  d date;
  item uuid;
begin
  if exists (select 1 from public.schedule_items where gym_id = g) then return; end if;
  for s in select * from (values
      ('Йога', 'Ольга', 1, '19:00'::time, 60, 16, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Йога', 'Ольга', 3, '19:00'::time, 60, 16, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Функциональный тренинг', 'Максим', 2, '20:00'::time, 55, 14, 'd2000000-0000-0000-0000-000000000001'::uuid),
      ('Функциональный тренинг', 'Максим', 4, '20:00'::time, 55, 14, 'd2000000-0000-0000-0000-000000000001'::uuid),
      ('Пилатес', 'Ника', 6, '11:00'::time, 55, 12, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Бокс', 'Тимур', 5, '19:30'::time, 60, 12, 'd2000000-0000-0000-0000-000000000001'::uuid),
      ('Стретчинг', 'Ольга', 7, '12:00'::time, 50, 16, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Утренняя растяжка', 'Ника', 2, '08:00'::time, 45, 10, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Утренняя растяжка', 'Ника', 4, '08:00'::time, 45, 10, 'd2000000-0000-0000-0000-000000000002'::uuid)
    ) t(title, trainer, dow, at_time, minutes, cap, zone) loop
    for w in 0..3 loop
      d := monday + w * 7 + s.dow - 1;
      insert into public.schedule_items (gym_id, kind, title, zone_id, trainer_name, starts_at, ends_at, capacity, recurrence_rule)
      values (g, 'class', s.title, s.zone, s.trainer, (d + s.at_time) at time zone tz,
              (d + s.at_time + make_interval(mins => s.minutes)) at time zone tz, s.cap, 'FREQ=WEEKLY')
      returning id into item;
      insert into public.bookings (gym_id, schedule_item_id, client_id, status, channel)
      select g, item, cl.id,
             case when (d + s.at_time) at time zone tz < now() then (case when random() < 0.85 then 'attended' else 'no_show' end)::public.booking_status
                  else 'booked' end,
             case when random() < 0.45 then 'app' else 'staff' end::public.booking_channel
        from public.clients cl
       where cl.gym_id = g and exists (select 1 from public.memberships mm where mm.client_id = cl.id and mm.status in ('active', 'frozen'))
       order by random()
       limit (s.cap * (0.4 + random() * 0.6))::int;
    end loop;
  end loop;
  -- персональные тренировки и сауна
  insert into public.schedule_items (gym_id, kind, title, zone_id, trainer_name, starts_at, ends_at, capacity)
  select g, 'personal', 'Персональная тренировка', 'd2000000-0000-0000-0000-000000000001', 'Максим',
         ((monday + 7 + n) + time '17:00') at time zone tz, ((monday + 7 + n) + time '18:00') at time zone tz, 1
    from generate_series(0, 4) n;
  insert into public.schedule_items (gym_id, kind, title, zone_id, starts_at, ends_at, capacity)
  select g, 'zone_slot', 'Сауна', 'd2000000-0000-0000-0000-000000000003',
         ((monday + 7 + n) + time '20:00') at time zone tz, ((monday + 7 + n) + time '21:30') at time zone tz, 6
    from generate_series(0, 6) n;
end $$;

-- Отметки контакта по части клиентов «в зоне риска» (для счётчика «вернулись»)
insert into public.risk_contacts (gym_id, client_id, reason, channel, note, contacted_at)
select r.gym_id, r.client_id, r.reason, (array['call','whatsapp','telegram'])[1 + floor(random() * 3)::int], 'демо', now() - interval '3 days'
  from public.v_client_risk r
 where r.gym_id = 'd1000000-0000-0000-0000-000000000001'
 order by random() limit 8
on conflict do nothing;
update public.risk_contacts set returned_at = now() - interval '1 day'
 where id in (select id from public.risk_contacts order by random() limit 3);

-- Статусы по датам
select public.run_maintenance();
