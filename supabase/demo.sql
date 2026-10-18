-- Публичные демо-залы core. для кнопки «Попробовать демо» (/demo): работают только на чтение (gyms.is_demo).
--   Desert Fit — ОАЭ, английский, AED, +971 (вход demo-ae@demo.core)
--   Атлет      — Россия, русский, ₽, +7      (вход demo-ru@demo.core)
-- Вход — одноразовой ссылкой с сервера, пароль никому не нужен. Повторный запуск ничего не дублирует.

select setseed(0.17);

create or replace function pg_temp.demo_owner(p_id uuid, p_email text) returns uuid
language plpgsql as $$
begin
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email,
          extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
  on conflict (id) do nothing;
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), p_id, p_id::text, jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
          'email', now(), now(), now())
  on conflict do nothing;
  return p_id;
end $$;

create or replace function pg_temp.demo_gym(p_gym uuid, p_region text, p_owner uuid, p_email text) returns void
language plpgsql as $$
declare
  ae boolean := p_region = 'AE';
  tz text := case when p_region = 'AE' then 'Asia/Dubai' else 'Europe/Moscow' end;
  today date := (now() at time zone (case when p_region = 'AE' then 'Asia/Dubai' else 'Europe/Moscow' end))::date;
  first_m text[];
  first_f text[];
  last_n text[];
  sources text[];
  z_gym uuid := gen_random_uuid();
  z_studio uuid := gen_random_uuid();
  z_sauna uuid := gen_random_uuid();
  plans uuid[];
  pick uuid;
  p_month uuid;
  p_pack uuid;
  p_quarter uuid;
  p_offpeak uuid;
  i int;
  c uuid;
  female boolean;
  name text;
  joined date;
  d date;
  pl public.membership_plans;
  m uuid;
  loyalty numeric;
  weekly numeric;
  fading boolean;
  ends date;
  v_day date;
  ts timestamptz;
  hr int;
  vleft int;
  method public.payment_method;
  monday date;
  s record;
  item uuid;
begin
  if exists (select 1 from public.gyms where id = p_gym) then return; end if;
  perform pg_temp.demo_owner(p_owner, p_email);

  if ae then
    first_m := array['Omar','Ahmed','Khalid','Yousef','Ali','Hassan','Rashid','James','Daniel','Arjun','Rahul','Michael','Luca','Adam','Karim','Ryan'];
    first_f := array['Fatima','Aisha','Mariam','Noura','Layla','Sara','Emma','Olivia','Priya','Anna','Sofia','Hannah','Zara','Mia','Leila','Chloe'];
    last_n := array['Al Mansoori','Al Hashimi','Khan','Patel','Sharma','Smith','Johnson','Haddad','Nasser','Rahman','Ibrahim','Fernandes','Brown','Wilson','Kumar','Saleh','Al Zaabi','Murphy','Rossi','Costa'];
    sources := array['Instagram','Instagram','Instagram','TikTok','Google Карты','Google Карты','Рекомендация','Рекомендация','Сайт','Вывеска'];
  else
    first_m := array['Иван','Алексей','Дмитрий','Сергей','Андрей','Максим','Артём','Никита','Павел','Егор','Михаил','Роман','Кирилл','Илья','Олег','Тимур'];
    first_f := array['Анна','Мария','Екатерина','Ольга','Наталья','Юлия','Дарья','Алина','Ксения','Полина','Виктория','Елена','София','Вера','Ирина','Алёна'];
    last_n := array['Иванов','Петров','Смирнов','Кузнецов','Попов','Васильев','Соколов','Михайлов','Новиков','Фёдоров','Морозов','Волков','Алексеев','Лебедев','Семёнов','Егоров','Павлов','Козлов','Орлов','Андреев'];
    sources := array['Instagram','Instagram','Рекомендация','Рекомендация','Рекомендация','Яндекс Карты','2ГИС','Вывеска','ВКонтакте','Сайт'];
  end if;

  insert into public.gyms (id, name, address, timezone, phone, region, is_demo, trial_until, paid_until, onboarded_at, created_at)
  values (p_gym,
          case when ae then 'Desert Fit' else 'Атлет' end,
          case when ae then 'Al Quoz 1, Dubai' else 'Москва, ул. Спортивная, 12' end,
          tz, case when ae then '+97143456789' else '+74951234567' end, p_region, true,
          current_date + 3650, current_date + 3650, now() - interval '300 days', now() - interval '300 days');
  if ae then
    update public.gyms set settings = jsonb_set(settings, '{message_templates}', '{
      "gone": "{name}, we haven''t seen you at {gym} for a while! Hope to see you at a workout soon — let us know if anything is in the way.",
      "expiring": "{name}, your {gym} membership ends on {date}. Renew in advance so you don''t miss a workout.",
      "declining": "{name}, we noticed you''ve been coming to {gym} less often. Can we find a better time or coach for you?",
      "not_renewed": "{name}, your {gym} membership has ended. Come back — we''ll help you renew."
    }'::jsonb) where id = p_gym;
  end if;

  insert into public.staff (gym_id, user_id, email, role, full_name)
  values (p_gym, p_owner, p_email, 'owner', case when ae then 'Sarah Ahmed' else 'Анна Смирнова' end);

  insert into public.zones (id, gym_id, name, capacity) values
    (z_gym, p_gym, case when ae then 'Gym floor' else 'Тренажёрный зал' end, 60),
    (z_studio, p_gym, case when ae then 'Studio' else 'Студия' end, 20),
    (z_sauna, p_gym, case when ae then 'Sauna' else 'Сауна' end, 6);

  insert into public.membership_plans (gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description)
  values (p_gym, case when ae then 'Single visit' else 'Разовое посещение' end, 'visits', case when ae then 7500 else 60000 end, 1, 1, 0, not ae,
          case when ae then 'One visit within a day' else 'Один визит в течение дня' end);
  insert into public.membership_plans (gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description)
  values (p_gym, case when ae then 'Month' else 'Месяц' end, 'unlimited', case when ae then 45000 else 350000 end, 30, null, 7, not ae,
          case when ae then 'Unlimited for 30 days' else 'Безлимит на 30 дней' end) returning id into p_month;
  insert into public.membership_plans (gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description)
  values (p_gym, case when ae then '8 classes' else '8 занятий' end, 'visits', case when ae then 40000 else 280000 end, 45, 8, 7, not ae,
          case when ae then '8 visits within 45 days' else '8 визитов за 45 дней' end) returning id into p_pack;
  insert into public.membership_plans (gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description)
  values (p_gym, case when ae then '3 months' else '3 месяца' end, 'unlimited', case when ae then 120000 else 900000 end, 90, null, 14, not ae,
          case when ae then 'Unlimited for 90 days' else 'Безлимит на 90 дней' end) returning id into p_quarter;
  insert into public.membership_plans (gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description)
  values (p_gym, case when ae then 'Off-peak' else 'Утренний' end, 'period', case when ae then 30000 else 250000 end, 30, null, 7, false,
          case when ae then 'Weekdays until 4 pm' else 'До 16:00 по будням' end) returning id into p_offpeak;
  -- «Месяц» продаётся чаще остальных, как в настоящих залах
  plans := array[p_month, p_month, p_month, p_pack, p_quarter, p_offpeak];

  for i in 1..260 loop
    female := random() < 0.5;
    if ae then
      name := (case when female then first_f[1 + floor(random() * array_length(first_f, 1))::int] else first_m[1 + floor(random() * array_length(first_m, 1))::int] end)
              || ' ' || last_n[1 + floor(random() * array_length(last_n, 1))::int];
    else
      name := last_n[1 + floor(random() * array_length(last_n, 1))::int] || case when female then 'а ' else ' ' end
              || (case when female then first_f[1 + floor(random() * array_length(first_f, 1))::int] else first_m[1 + floor(random() * array_length(first_m, 1))::int] end);
    end if;
    joined := today - (1 + floor(random() * 290))::int;
    insert into public.clients (gym_id, full_name, phone, gender, source, tags, consent_pd_at, consent_pd_text,
                                consent_marketing_at, consent_marketing_text, created_at)
    values (p_gym, name, case when ae then '+97150' else '+7926' end || lpad(i::text, 7, '0'),
            case when female then 'female' else 'male' end,
            sources[1 + floor(random() * array_length(sources, 1))::int],
            case when random() < 0.12 then array['vip'] else '{}' end,
            joined::timestamp at time zone tz, case when ae then 'Consent given at the front desk (demo)' else 'Согласие получено на ресепшене (демо)' end,
            case when random() < 0.7 then joined::timestamp at time zone tz end,
            case when ae then 'Marketing consent (demo)' else 'Согласие на рассылки (демо)' end, joined::timestamp at time zone tz)
    returning id into c;

    loyalty := 0.55 + random() * 0.4;
    weekly := 1.2 + random() * 2.6;
    fading := random() < 0.08;
    d := joined;
    m := null;
    loop
      pick := plans[1 + floor(random() * 6)::int];
      select * into pl from public.membership_plans where id = pick;
      ends := d + pl.duration_days - 1;
      method := (array['card','card','cash'])[1 + floor(random() * 3)::int]::public.payment_method;
      insert into public.memberships (gym_id, client_id, plan_id, plan_name, kind, starts_on, ends_on, visits_left,
                                      freeze_days_max, status, price_paid, renewed_from_id, created_at)
      values (p_gym, c, pl.id, pl.name, pl.kind, d, ends, pl.visits_limit, pl.freeze_days_max,
              case when ends < today then 'expired' else 'active' end::public.membership_status, pl.price, m,
              (d::timestamp + time '10:00' + make_interval(mins => floor(random() * 600)::int)) at time zone tz)
      returning id into m;
      insert into public.payments (gym_id, client_id, membership_id, amount, method, status, paid_at, created_at, description)
      values (p_gym, c, m, pl.price, method, 'succeeded',
              (d::timestamp + time '10:00' + make_interval(mins => floor(random() * 600)::int)) at time zone tz,
              (d::timestamp + time '10:00') at time zone tz, 'Абонемент «' || pl.name || '»');

      vleft := coalesce(pl.visits_limit, 1000);
      v_day := d;
      while v_day <= least(ends, today) and vleft > 0 loop
        if random() < ((weekly / 7.0) * (case when fading and v_day > today - 14 then 0.15 else 1 end)) then
          hr := case when random() < 0.3 then 6 + floor(random() * 4)::int
                     when random() < 0.75 then 17 + floor(random() * 5)::int
                     else 11 + floor(random() * 6)::int end;
          ts := (v_day::timestamp + make_interval(hours => hr, mins => floor(random() * 60)::int)) at time zone tz;
          if ts < now() - interval '2 hours' then
            insert into public.visits (gym_id, client_id, membership_id, checked_in_at, checked_out_at, method)
            values (p_gym, c, m, ts, ts + make_interval(mins => 50 + floor(random() * 60)::int),
                    case when random() < 0.65 then 'qr' else 'manual' end::public.visit_method);
            vleft := vleft - 1;
          end if;
        end if;
        v_day := v_day + 1;
      end loop;
      if pl.visits_limit is not null then
        update public.memberships set visits_left = greatest(vleft, 0) where id = m;
      end if;

      exit when ends >= today;
      exit when random() > loyalty;
      d := ends + 1 + case when random() < 0.25 then floor(random() * 10)::int else 0 end;
      exit when d > today;
    end loop;
  end loop;

  update public.clients cl set last_visit_at = v.mx
    from (select client_id, max(checked_in_at) mx from public.visits where gym_id = p_gym group by client_id) v
   where v.client_id = cl.id;

  insert into public.visits (gym_id, client_id, membership_id, checked_in_at, method)
  select p_gym, m2.client_id, m2.id, now() - make_interval(mins => floor(random() * 80)::int), 'qr'
    from public.memberships m2
   where m2.gym_id = p_gym and m2.status = 'active' and m2.starts_on <= today and m2.ends_on >= today and m2.kind <> 'visits'
   order by random() limit 12;

  -- расписание на 4 недели
  monday := date_trunc('week', (now() at time zone tz))::date - 7;
  for s in select * from (values
      (case when ae then 'Yoga' else 'Йога' end, case when ae then 'Layla' else 'Ольга' end, 1, '19:00'::time, 60, 16, z_studio),
      (case when ae then 'Yoga' else 'Йога' end, case when ae then 'Layla' else 'Ольга' end, 3, '19:00'::time, 60, 16, z_studio),
      (case when ae then 'Functional training' else 'Функциональный тренинг' end, case when ae then 'Marcus' else 'Максим' end, 2, '20:00'::time, 55, 14, z_gym),
      (case when ae then 'Functional training' else 'Функциональный тренинг' end, case when ae then 'Marcus' else 'Максим' end, 4, '20:00'::time, 55, 14, z_gym),
      (case when ae then 'Pilates' else 'Пилатес' end, case when ae then 'Noura' else 'Ника' end, 6, '11:00'::time, 55, 12, z_studio),
      (case when ae then 'Boxing' else 'Бокс' end, case when ae then 'Khalid' else 'Тимур' end, 5, '19:30'::time, 60, 12, z_gym),
      (case when ae then 'Stretching' else 'Стретчинг' end, case when ae then 'Layla' else 'Ольга' end, 7, '12:00'::time, 50, 16, z_studio)
    ) t(title, trainer, dow, at_time, minutes, cap, zone) loop
    for w in 0..3 loop
      d := monday + w * 7 + s.dow - 1;
      insert into public.schedule_items (gym_id, kind, title, zone_id, trainer_name, starts_at, ends_at, capacity, recurrence_rule)
      values (p_gym, 'class', s.title, s.zone, s.trainer, (d + s.at_time) at time zone tz,
              (d + s.at_time + make_interval(mins => s.minutes)) at time zone tz, s.cap, 'FREQ=WEEKLY')
      returning id into item;
      insert into public.bookings (gym_id, schedule_item_id, client_id, status, channel)
      select p_gym, item, cl.id,
             case when (d + s.at_time) at time zone tz < now() then (case when random() < 0.85 then 'attended' else 'no_show' end)::public.booking_status
                  else 'booked' end,
             case when random() < 0.45 then 'app' else 'staff' end::public.booking_channel
        from public.clients cl
       where cl.gym_id = p_gym and exists (select 1 from public.memberships mm where mm.client_id = cl.id and mm.status in ('active', 'frozen'))
       order by random()
       limit (s.cap * (0.4 + random() * 0.6))::int;
    end loop;
  end loop;
end $$;

select pg_temp.demo_gym('d1000000-0000-0000-0000-0000000000a1', 'AE', 'd0000000-0000-0000-0000-0000000000a1', 'demo-ae@demo.core');
select pg_temp.demo_gym('d1000000-0000-0000-0000-0000000000b1', 'RU', 'd0000000-0000-0000-0000-0000000000b1', 'demo-ru@demo.core');

select public.run_maintenance();

-- отметки контакта по части клиентов «в зоне риска»: счётчик «вернулись после контакта»
insert into public.risk_contacts (gym_id, client_id, reason, channel, note, contacted_at)
select r.gym_id, r.client_id, r.reason, (array['call','whatsapp','telegram'])[1 + floor(random() * 3)::int], 'demo', now() - interval '6 days'
  from public.v_client_risk r
 where r.gym_id in ('d1000000-0000-0000-0000-0000000000a1', 'd1000000-0000-0000-0000-0000000000b1')
   and not exists (select 1 from public.risk_contacts rc where rc.gym_id = r.gym_id)
 order by random() limit 18
on conflict do nothing;
update public.risk_contacts set returned_at = now() - interval '2 days'
 where note = 'demo' and returned_at is null and random() < 0.45;
