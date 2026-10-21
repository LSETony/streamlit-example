-- iOS-приложение core.: клиенты входят по email-коду (Supabase Auth), а не только по телефону.
-- 1) link_account находит записи клиента в залах по подтверждённому email или телефону аккаунта.
-- 2) join_gym принимает телефон от клиента, если в аккаунте его нет (вход по email), и не привязывает
--    чужую запись по неподтверждённому номеру.
-- 3) public_gym отдаёт признак «продаётся онлайн», чтобы приложение показывало только тарифы для покупки.

create or replace function public.link_account() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_phone text;
  v_email text;
  v_result jsonb;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  select public.normalize_phone(phone),
         case when email_confirmed_at is not null then lower(nullif(email, '')) end
    into v_phone, v_email
    from auth.users where id = auth.uid();
  if v_phone is null and v_email is null then
    perform private.fail('PHONE_REQUIRED', 'В аккаунте не указан номер телефона');
  end if;

  update public.clients set user_id = auth.uid()
   where deleted_at is null and user_id is null
     and ((v_phone is not null and phone = v_phone) or (v_email is not null and lower(email) = v_email));

  select coalesce(jsonb_agg(jsonb_build_object('client_id', c.id, 'gym_id', g.id, 'gym_name', g.name,
                                               'full_name', c.full_name) order by g.name), '[]')
    into v_result
    from public.clients c join public.gyms g on g.id = c.gym_id
   where c.user_id = auth.uid() and c.deleted_at is null;
  return jsonb_build_object('phone', v_phone, 'email', v_email, 'clients', v_result);
end $$;

drop function if exists public.join_gym(uuid, text, boolean);
create or replace function public.join_gym(p_gym uuid, p_full_name text, p_marketing_consent boolean default false,
                                           p_phone text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_auth_phone text;
  v_phone text;
  v_email text;
  v_id uuid;
  v_owner uuid;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  if not private.gym_writable(p_gym) then perform private.fail('GYM_READ_ONLY', 'Зал временно не принимает новых клиентов'); end if;
  if coalesce(trim(p_full_name), '') = '' then perform private.fail('INVALID_INPUT', 'Укажите имя и фамилию'); end if;
  select public.normalize_phone(phone),
         case when email_confirmed_at is not null then nullif(email, '') end
    into v_auth_phone, v_email
    from auth.users where id = auth.uid();
  v_phone := coalesce(v_auth_phone, public.normalize_phone(p_phone));
  if v_phone is null then perform private.fail('PHONE_REQUIRED', 'Укажите номер телефона'); end if;

  select id, user_id into v_id, v_owner from public.clients
   where gym_id = p_gym and phone = v_phone and deleted_at is null;
  if v_id is not null then
    if v_owner = auth.uid() then return v_id; end if;
    -- номер подтверждён входом по SMS — запись можно привязать; номер введён вручную — нельзя
    if v_auth_phone is not null and v_owner is null then
      update public.clients set user_id = auth.uid() where id = v_id;
      return v_id;
    end if;
    perform private.fail('PHONE_TAKEN', 'Этот номер уже есть в зале. Войдите по номеру телефона или попросите ресепшен добавить ваш email');
  end if;

  insert into public.clients (gym_id, user_id, full_name, phone, email, source, consent_pd_at, consent_pd_text,
                              consent_marketing_at, consent_marketing_text)
  values (p_gym, auth.uid(), trim(p_full_name), v_phone, v_email, 'приложение core.', now(),
          'Согласие на обработку персональных данных дано в приложении core.',
          case when p_marketing_consent then now() end,
          case when p_marketing_consent then 'Согласие на рассылки дано в приложении core.' end)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.public_gym(p_gym uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', g.id, 'name', g.name, 'address', g.address, 'phone', g.phone, 'logo_url', g.logo_url,
    'region', g.region, 'currency', g.currency, 'timezone', g.timezone,
    'schedule', coalesce((public.gym_features(g.id) ->> 'schedule')::boolean, false),
    'plans', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'description', p.description, 'kind', p.kind,
                                          'price', p.price, 'duration_days', p.duration_days,
                                          'visits_limit', p.visits_limit, 'sold_online', p.sold_online) order by p.price)
        from public.membership_plans p where p.gym_id = g.id and p.active), '[]'))
    from public.gyms g where g.id = p_gym
$$;

revoke execute on function public.join_gym(uuid, text, boolean, text) from public, anon;
grant execute on function public.join_gym(uuid, text, boolean, text) to authenticated, service_role;
grant execute on function public.link_account() to authenticated, service_role;
grant execute on function public.public_gym(uuid) to anon, authenticated, service_role;
