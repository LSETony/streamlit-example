-- Регионы: Россия и ОАЭ. Регион выбирается при создании зала и задаёт валюту, телефонный код,
-- часовой пояс по умолчанию и язык шаблонов сообщений. Суммы по-прежнему хранятся в сотых долях валюты зала
-- (копейки для RUB, филсы для AED).

alter table public.gyms
  add column region text not null default 'RU' check (region in ('RU', 'AE')),
  add column currency text generated always as (case region when 'AE' then 'AED' else 'RUB' end) stored;

-- Регион нельзя сменить после создания: цены и оплаты зала записаны в его валюте
create or replace function private.gyms_region_locked() returns trigger
language plpgsql as $$
begin
  if new.region is distinct from old.region then
    raise exception 'Регион зала нельзя изменить после создания' using hint = 'REGION_LOCKED';
  end if;
  return new;
end $$;
create trigger gyms_region_locked before update of region on public.gyms
  for each row execute function private.gyms_region_locked();

-- Телефоны: российские (+7) и эмиратские (+971) номера в локальной записи приводятся к международному формату
create or replace function public.normalize_phone(p text) returns text
language plpgsql immutable as $$
declare
  d text;
begin
  if p is null then return null; end if;
  d := regexp_replace(p, '\D', '', 'g');
  if d = '' then return null; end if;
  if length(d) = 11 and left(d, 1) in ('7', '8') then
    return '+7' || substr(d, 2);
  elsif length(d) = 10 and left(d, 1) = '9' then
    return '+7' || d;
  elsif length(d) = 10 and left(d, 2) = '05' then      -- ОАЭ: 050 123 4567
    return '+971' || substr(d, 2);
  elsif length(d) = 9 and left(d, 1) = '5' then         -- ОАЭ: 50 123 4567
    return '+971' || d;
  elsif length(d) = 12 and left(d, 3) = '971' then      -- ОАЭ: 971 50 123 4567
    return '+' || d;
  elsif left(p, 1) = '+' and length(d) between 10 and 15 then
    return '+' || d;
  end if;
  return null;
end $$;

-- Создание зала с регионом: для ОАЭ — часовой пояс Дубая и шаблоны сообщений на английском
drop function if exists public.create_gym(text, text, text, text, text);
create function public.create_gym(p_name text, p_owner_name text, p_address text default null,
                                  p_timezone text default null, p_phone text default null, p_region text default 'RU')
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
  v_email text;
  v_region text := coalesce(p_region, 'RU');
  v_tz text;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  if v_region not in ('RU', 'AE') then perform private.fail('INVALID_REGION', 'Выберите регион: Россия или ОАЭ'); end if;
  if exists (select 1 from public.staff where user_id = auth.uid() and role = 'owner' and active) then
    perform private.fail('GYM_EXISTS', 'У вас уже есть зал. Несколько залов в одном кабинете — после MVP');
  end if;
  v_tz := coalesce(nullif(p_timezone, ''), case v_region when 'AE' then 'Asia/Dubai' else 'Europe/Moscow' end);
  perform now() at time zone v_tz;   -- валидация часового пояса
  select email into v_email from auth.users where id = auth.uid();
  insert into public.gyms (name, address, timezone, phone, region)
  values (p_name, p_address, v_tz, public.normalize_phone(p_phone), v_region) returning id into v_gym;
  if v_region = 'AE' then
    update public.gyms set settings = jsonb_set(settings, '{message_templates}', '{
      "gone": "{name}, we haven''t seen you at {gym} for a while! Hope to see you at a workout soon — let us know if anything is in the way.",
      "expiring": "{name}, your {gym} membership ends on {date}. Renew in advance so you don''t miss a workout.",
      "declining": "{name}, we noticed you''ve been coming to {gym} less often. Can we find a better time or coach for you?",
      "not_renewed": "{name}, your {gym} membership has ended. Come back — we''ll help you renew."
    }'::jsonb) where id = v_gym;
  end if;
  insert into public.staff (gym_id, user_id, email, role, full_name)
  values (v_gym, auth.uid(), coalesce(v_email, auth.uid()::text), 'owner', p_owner_name);
  return v_gym;
end $$;
revoke execute on function public.create_gym(text, text, text, text, text, text) from public, anon;
grant execute on function public.create_gym(text, text, text, text, text, text) to authenticated, service_role;

-- Каталог залов для приложения: регион и валюта, чтобы показывать цены в нужной валюте
create or replace view public.public_gyms as
  select id, name, address, timezone, phone, logo_url, region, currency from public.gyms;
grant select on public.public_gyms to authenticated;

grant execute on function private.gyms_region_locked() to authenticated, service_role;
