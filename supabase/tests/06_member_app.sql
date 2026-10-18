-- Приложение клиента и виджет записи: расписание и цены доступны без входа и без персональных данных
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;
grant execute on all functions in schema tests to anon, authenticated, service_role;
grant usage on schema tests to anon;

insert into auth.users (id, phone) values (tests.id('client_user'), '79161234567') on conflict (id) do nothing;
update public.clients set user_id = tests.id('client_user') where id = tests.id('client_a1');

-- без входа: занятия с числом занятых мест, без чужих записей и имён
set local role anon;
select tests.assert(jsonb_array_length(public.public_schedule(tests.id('gym_a'))) >= 1, 'аноним видит занятия');
select tests.assert((public.public_schedule(tests.id('gym_a')) -> 0 ->> 'booked')::int = 1, 'видно число занятых мест');
select tests.assert(public.public_schedule(tests.id('gym_a')) -> 0 -> 'my_booking_id' = 'null'::jsonb, 'аноним не видит записи');
select tests.assert(public.public_schedule(tests.id('gym_a'))::text not like '%Петров%', 'нет имён клиентов');
select tests.assert(jsonb_array_length(public.public_gym(tests.id('gym_a')) -> 'plans') = 2, 'аноним видит тарифы');
select tests.assert(public.public_gym(tests.id('gym_a'))::text not like '%secret%', 'нет ключей зала');
reset role;

-- клиент видит свою запись
select tests.login(tests.id('client_user'));
select tests.assert(public.public_schedule(tests.id('gym_a')) -> 0 ->> 'my_booking_id' is not null, 'клиент видит свою запись');
reset role;

select 'member app: OK' as result;
rollback;
