-- Несколько залов в одном аккаунте: владелец сети создаёт новые залы и переключается между ними в кабинете.
-- Ограничение на 20 залов защищает от злоупотребления пробными периодами.

-- Создание зала: для ОАЭ — часовой пояс Дубая и шаблоны сообщений на английском
create or replace function public.create_gym(p_name text, p_owner_name text, p_address text default null,
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
  if (select count(*) from public.staff where user_id = auth.uid() and role = 'owner' and active) >= 20 then
    perform private.fail('GYM_LIMIT', 'В одном аккаунте можно создать до 20 залов — напишите нам, если нужно больше');
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
