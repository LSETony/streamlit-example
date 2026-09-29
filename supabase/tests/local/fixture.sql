-- Общие данные для SQL-тестов: два зала (А и Б), сотрудники всех ролей, клиенты с абонементами,
-- визитами, бронями и оплатами. Подключается из тестов через \ir и работает внутри их транзакции.

create schema if not exists tests;
grant usage on schema tests to authenticated, service_role;

-- Войти как пользователь (роль authenticated + auth.uid())
create or replace function tests.login(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(p_user::text, ''), true);
  perform set_config('role', 'authenticated', true);
end $$;

-- Ожидаем ошибку с машинным кодом (hint) или SQLSTATE
create or replace function tests.expect_error(p_sql text, p_code text) returns void language plpgsql as $$
declare
  v_hint text;
  v_state text;
  v_msg text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate, v_msg = message_text;
    if coalesce(v_hint, '') = p_code or v_state = p_code then
      return;
    end if;
    raise exception 'Ожидалась ошибка %, получено % / %: %', p_code, v_hint, v_state, v_msg;
  end;
  raise exception 'Ожидалась ошибка %, но запрос выполнился: %', p_code, p_sql;
end $$;

create or replace function tests.id(p_key text) returns uuid language sql stable as $$
  select current_setting('t.' || p_key)::uuid
$$;
create or replace function tests.put(p_key text, p_val uuid) returns uuid language sql as $$
  select set_config('t.' || p_key, p_val::text, false)::uuid
$$;

grant execute on all functions in schema tests to authenticated, service_role;

-- Пользователи
insert into auth.users (id, email, phone) values
  ('00000000-0000-0000-0000-00000000a001', 'owner-a@test.ru', null),
  ('00000000-0000-0000-0000-00000000a002', 'admin-a@test.ru', null),
  ('00000000-0000-0000-0000-00000000a003', 'reception-a@test.ru', null),
  ('00000000-0000-0000-0000-00000000b001', 'owner-b@test.ru', null),
  ('00000000-0000-0000-0000-00000000c001', null, '79161234567'),   -- клиент в приложении
  ('00000000-0000-0000-0000-00000000c002', null, '79990000000'),   -- новый пользователь приложения
  ('00000000-0000-0000-0000-00000000f001', 'team@core.ru', null);  -- команда core.
insert into public.platform_admins (user_id) values ('00000000-0000-0000-0000-00000000f001');

select tests.put('owner_a', '00000000-0000-0000-0000-00000000a001');
select tests.put('admin_a', '00000000-0000-0000-0000-00000000a002');
select tests.put('reception_a', '00000000-0000-0000-0000-00000000a003');
select tests.put('owner_b', '00000000-0000-0000-0000-00000000b001');
select tests.put('client_user', '00000000-0000-0000-0000-00000000c001');
select tests.put('new_user', '00000000-0000-0000-0000-00000000c002');
select tests.put('platform', '00000000-0000-0000-0000-00000000f001');

-- Залы создают владельцы (самостоятельная регистрация)
select tests.login(tests.id('owner_a'));
select tests.put('gym_a', public.create_gym('Зал А', 'Анна Владелец', 'Москва, ул. Тестовая, 1'));
reset role;
select tests.login(tests.id('owner_b'));
select tests.put('gym_b', public.create_gym('Зал Б', 'Борис Владелец'));
reset role;

-- Приглашённые сотрудники зала А (в кабинете это делает серверное действие с service key)
insert into public.staff (gym_id, user_id, email, role, full_name) values
  (tests.id('gym_a'), tests.id('admin_a'), 'admin-a@test.ru', 'admin', 'Алла Администратор'),
  (tests.id('gym_a'), tests.id('reception_a'), 'reception-a@test.ru', 'reception', 'Рита Ресепшен');

-- Данные зала А (от имени владельца)
select tests.login(tests.id('owner_a'));
with x as (insert into public.membership_plans
  (gym_id, name, kind, price, duration_days, freeze_days_max, sold_online)
  values (tests.id('gym_a'), 'Месяц', 'period', 300000, 30, 14, true) returning id) select tests.put('plan_month', id) from x;
with x as (insert into public.membership_plans
  (gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max)
  values (tests.id('gym_a'), '10 визитов', 'visits', 250000, 60, 10, 7) returning id) select tests.put('plan_10', id) from x;
with x as (insert into public.zones (gym_id, name, capacity)
  values (tests.id('gym_a'), 'Тренажёрный зал', 40) returning id) select tests.put('zone_a', id) from x;
with x as (insert into public.clients (gym_id, full_name, phone, source, consent_pd_at)
  values (tests.id('gym_a'), 'Иван Петров', '8 (916) 123-45-67', 'instagram', now()) returning id) select tests.put('client_a1', id) from x;
with x as (insert into public.clients (gym_id, full_name, phone, source, consent_pd_at, consent_marketing_at)
  values (tests.id('gym_a'), 'Мария Сидорова', '+7 903 000-00-02', 'рекомендация', now(), now()) returning id) select tests.put('client_a2', id) from x;
select public.sell_membership(tests.id('client_a1'), tests.id('plan_month'), 'cash');
select public.sell_membership(tests.id('client_a2'), tests.id('plan_10'), 'card');
select public.checkin_manual(tests.id('client_a2'));
select public.create_schedule_series(tests.id('gym_a'), 'Йога',
  ((now() at time zone 'Europe/Moscow')::date + 1 + time '19:00'), 60, 2, 'class', tests.id('zone_a'), 'Ольга');
reset role;
select tests.put('class_a', (select id from public.schedule_items where gym_id = tests.id('gym_a') and title = 'Йога'));

select tests.login(tests.id('reception_a'));
select public.book_class(tests.id('class_a'), tests.id('client_a1'));
select public.freeze_membership(
  (select id from public.memberships where client_id = tests.id('client_a1')),
  private.gym_today(tests.id('gym_a')) + 5, private.gym_today(tests.id('gym_a')) + 7, 'отпуск');
select public.mark_contacted(tests.id('client_a2'), 'gone', 'call', 'обещала прийти');
reset role;

-- Клиент входит в приложение, привязывается и регистрирует устройство
select tests.login(tests.id('client_user'));
select public.link_account();
select public.register_device('ios', 'apns-token-1');
reset role;

-- Данные зала Б
select tests.login(tests.id('owner_b'));
with x as (insert into public.membership_plans
  (gym_id, name, kind, price, duration_days) values (tests.id('gym_b'), 'Безлимит', 'unlimited', 500000, 30) returning id) select tests.put('plan_b', id) from x;
with x as (insert into public.clients (gym_id, full_name, phone)
  values (tests.id('gym_b'), 'Борис Клиентов', '+79160000001') returning id) select tests.put('client_b1', id) from x;
select public.sell_membership(tests.id('client_b1'), tests.id('plan_b'), 'cash');
select public.checkin_manual(tests.id('client_b1'));
reset role;
