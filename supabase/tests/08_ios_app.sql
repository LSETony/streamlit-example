-- iOS-приложение: вход по email привязывает клиента зала по подтверждённому email, выбор зала с телефоном
begin;
\ir local/fixture.sql

create or replace function tests.assert(p_cond boolean, p_msg text) returns void language plpgsql as $$
begin
  if p_cond is not true then raise exception 'ПРОВАЛ: %', p_msg; end if;
end $$;
grant execute on all functions in schema tests to authenticated, service_role;

-- ресепшен завёл клиента с email (запись ещё не привязана к приложению)
with x as (insert into public.clients (gym_id, full_name, phone, email, consent_pd_at)
  values (tests.id('gym_a'), 'Иван Почтов', '+7 903 555-44-33', 'Ivan@Example.com', now()) returning id)
select tests.put('client_mail', id) from x;
-- уже привязанную к другому аккаунту запись email не перехватывает
update public.clients set email = 'ivan@example.com' where id = tests.id('client_a1');
select tests.put('mail_user', gen_random_uuid());
select tests.put('mail_unconfirmed', gen_random_uuid());
select tests.put('mail_new', gen_random_uuid());
insert into auth.users (id, email, email_confirmed_at) values
  (tests.id('mail_user'), 'ivan@example.com', now()),
  (tests.id('mail_unconfirmed'), 'ivan@example.com', null),
  (tests.id('mail_new'), 'new@example.com', now());

-- неподтверждённый email не привязывает
select tests.login(tests.id('mail_unconfirmed'));
select tests.expect_error('select public.link_account()', 'PHONE_REQUIRED');
reset role;

-- подтверждённый email находит клиента без учёта регистра
select tests.login(tests.id('mail_user'));
select tests.assert(jsonb_array_length(public.link_account() -> 'clients') = 1, 'клиент найден по email');
select tests.assert((select count(*) from public.clients where user_id = tests.id('mail_user')) = 1, 'привязана только свободная запись');
reset role;

-- новый клиент выбирает зал: без телефона нельзя, чужой номер не привязывается, свой — создаёт запись
select tests.login(tests.id('mail_new'));
select tests.expect_error(format('select public.join_gym(%L, ''Новый Клиент'')', tests.id('gym_a')), 'PHONE_REQUIRED');
select tests.expect_error(format('select public.join_gym(%L, ''Новый Клиент'', false, ''+7 903 000-00-02'')', tests.id('gym_a')), 'PHONE_TAKEN');
select tests.put('joined', public.join_gym(tests.id('gym_a'), 'Новый Клиент', true, '+7 999 111-22-33'));
select tests.assert(jsonb_array_length(public.link_account() -> 'clients') = 1, 'новый клиент привязан');
reset role;
select tests.assert((select email = 'new@example.com' and phone = '+79991112233' and consent_marketing_at is not null
                       from public.clients where id = tests.id('joined')), 'email и телефон сохранены');
select tests.assert((select user_id is null from public.clients where id = tests.id('client_a2')), 'чужая запись не тронута');
select tests.assert(public.public_gym(tests.id('gym_a')) -> 'plans' -> 0 ? 'sold_online', 'тарифы с признаком продажи онлайн');

select 'ios app: OK' as result;
rollback;
