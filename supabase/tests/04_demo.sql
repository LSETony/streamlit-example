-- Демо-залы: только чтение на уровне базы, даже если обойти интерфейс
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;
grant execute on all functions in schema tests to authenticated, service_role;

select tests.put('demo_owner', gen_random_uuid());
insert into auth.users (id, email) values (tests.id('demo_owner'), 'demo@demo.test');
select tests.login(tests.id('demo_owner'));
select tests.put('demo_gym', public.create_gym('Demo Gym', 'Demo Owner', null, null, null, 'AE'));
reset role;
update public.gyms set is_demo = true where id = tests.id('demo_gym');

select tests.assert(not private.gym_writable(tests.id('demo_gym')), 'демо-зал не принимает изменения');
select tests.login(tests.id('demo_owner'));
select tests.expect_error(format('select private.require_staff(%L)', tests.id('demo_gym')), 'DEMO_READ_ONLY');
-- чтение работает
select tests.assert(private.require_staff(tests.id('demo_gym'), null, false) is not null, 'демо-зал можно смотреть');
reset role;

select 'demo: OK' as result;
rollback;
