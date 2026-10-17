-- Тренер: видит клиентов и расписание, отмечает посещаемость; не продаёт, не создаёт клиентов, не видит оплаты
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;
grant execute on all functions in schema tests to authenticated, service_role;

select tests.put('trainer_a', gen_random_uuid());
insert into auth.users (id, email) values (tests.id('trainer_a'), 'trainer-a@test.ru');
insert into public.staff (gym_id, user_id, email, role, full_name)
  values (tests.id('gym_a'), tests.id('trainer_a'), 'trainer-a@test.ru', 'trainer', 'Тимур Тренер');

-- запись клиента на занятие уже создана в фикстуре
select tests.put('booking_a', (select id from public.bookings where schedule_item_id = tests.id('class_a') and client_id = tests.id('client_a1')));

select tests.login(tests.id('trainer_a'));
select tests.assert((select count(*) from public.clients where gym_id = tests.id('gym_a')) > 0, 'тренер видит клиентов');
select tests.assert((select count(*) from public.schedule_items where gym_id = tests.id('gym_a')) > 0, 'тренер видит расписание');
select tests.assert((select count(*) from public.payments where gym_id = tests.id('gym_a')) = 0, 'тренер не видит оплаты');
select tests.expect_error(format('select public.sell_membership(%L, %L, ''cash'')', tests.id('client_a2'), tests.id('plan_month')), 'FORBIDDEN');
select tests.expect_error(format('insert into public.clients (gym_id, full_name, phone, consent_pd_at) values (%L, ''X'', ''+79161112233'', now())', tests.id('gym_a')), '42501');
select public.mark_booking(tests.id('booking_a'), 'attended');
reset role;
select tests.assert((select status = 'attended' from public.bookings where id = tests.id('booking_a')), 'тренер отметил «пришёл»');

select 'trainer: OK' as result;
rollback;
