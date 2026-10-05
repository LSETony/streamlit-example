-- Регионы: зал в ОАЭ получает дирхамы, часовой пояс Дубая, английские шаблоны; регион нельзя сменить; телефоны +971
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;
grant execute on all functions in schema tests to authenticated, service_role;

select tests.put('uae_owner', gen_random_uuid());
insert into auth.users (id, email) values (tests.id('uae_owner'), 'owner@uae.test');

select tests.login(tests.id('uae_owner'));
select tests.expect_error('select public.create_gym(''X'', ''Y'', p_region => ''US'')', 'INVALID_REGION');
select tests.put('uae_gym', public.create_gym('Desert Fit', 'Sarah Ahmed', 'Al Quoz, Dubai', null, '050 123 4567', 'AE'));
reset role;

select tests.assert(region = 'AE' and currency = 'AED' and timezone = 'Asia/Dubai', 'зал ОАЭ: AED и Дубай')
  from public.gyms where id = tests.id('uae_gym');
select tests.assert(phone = '+971501234567', 'телефон зала приведён к +971') from public.gyms where id = tests.id('uae_gym');
select tests.assert(settings #>> '{message_templates,gone}' like '%haven''t seen you%', 'английские шаблоны сообщений')
  from public.gyms where id = tests.id('uae_gym');

-- клиент с локальным эмиратским номером
select tests.login(tests.id('uae_owner'));
insert into public.clients (gym_id, full_name, phone, consent_pd_at)
  values (tests.id('uae_gym'), 'Omar Khalid', '055 765 4321', now());
reset role;
select tests.assert(exists (select 1 from public.clients where gym_id = tests.id('uae_gym') and phone = '+971557654321'),
  'телефон клиента в ОАЭ приведён к +971');

-- регион не меняется после создания (даже от имени сервиса: у владельца прямой записи в gyms нет)
select tests.expect_error(format('update public.gyms set region = ''RU'' where id = %L', tests.id('uae_gym')), 'REGION_LOCKED');

-- российский зал по умолчанию
select tests.assert(public.normalize_phone('8 (916) 123-45-67') = '+79161234567', 'российские номера как раньше');
select tests.assert((select currency from public.gyms where region = 'RU' limit 1) = 'RUB', 'российские залы в рублях');

select 'regions: OK' as result;
rollback;
