-- core. MVP — бизнес-логика (раздел 5). Всё, что меняет деньги, абонементы, визиты и брони,
-- выполняется только здесь: функции security definer сами проверяют роль вызывающего.
--
-- Ошибки: SQLSTATE P0001, message — текст для человека, hint — машинный код
-- (MEMBERSHIP_FROZEN, CLASS_FULL, ...). Edge Functions отдают их как {code, message}.

-- ---------------------------------------------------------------------------
-- Инфраструктура
-- ---------------------------------------------------------------------------
create or replace function private.fail(p_code text, p_message text) returns void
language plpgsql as $$
begin
  raise exception using errcode = 'P0001', message = p_message, hint = p_code;
end $$;

create or replace function private.fmt_date(d date) returns text
language sql immutable as $$ select to_char(d, 'DD.MM.YYYY') $$;

-- Проверяет, что вызывающий — активный сотрудник зала с одной из ролей; возвращает staff.id
create or replace function private.require_staff(p_gym uuid, p_roles public.staff_role[] default null,
                                                 p_write boolean default true) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_id uuid;
begin
  select id into v_id from public.staff
   where gym_id = p_gym and user_id = auth.uid() and active
     and (p_roles is null or role = any (p_roles));
  if v_id is null then
    perform private.fail('FORBIDDEN', 'Недостаточно прав для этого действия');
  end if;
  if p_write and not private.gym_writable(p_gym) then
    perform private.fail('GYM_READ_ONLY', 'Пробный период закончился: кабинет работает в режиме «только чтение»');
  end if;
  return v_id;
end $$;

-- Флаги функций: умолчания тарифа core. + индивидуальные настройки зала (FR-10.2)
create or replace function public.gym_features(p_gym uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select (case g.core_plan
            when 'start' then '{"dashboard":true,"risk":true,"schedule":true,"online_payments":true,
                                "import":true,"notifications":true,"export":true,"audit":true}'::jsonb
            else '{"dashboard":true,"risk":true,"schedule":true,"online_payments":true,
                   "import":true,"notifications":true,"export":true,"audit":true}'::jsonb
          end) || g.features
    from public.gyms g where g.id = p_gym
$$;

create or replace function private.require_feature(p_gym uuid, p_feature text) returns void
language plpgsql stable as $$
begin
  if coalesce((public.gym_features(p_gym) ->> p_feature)::boolean, false) is not true then
    perform private.fail('FEATURE_DISABLED', 'Функция недоступна на тарифе зала');
  end if;
end $$;

-- Постановка уведомления в очередь (раздел 5.9): согласие на рассылки и «тихие часы» зала
create or replace function private.enqueue_notification(
  p_client uuid, p_kind text, p_service boolean, p_title text, p_body text,
  p_data jsonb default '{}', p_send_after timestamptz default now(), p_dedupe text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  c record;
  v_local timestamp;
  v_send timestamptz := greatest(p_send_after, now());
  v_id uuid;
begin
  select cl.id, cl.gym_id, cl.consent_marketing_at, cl.deleted_at, g.timezone
    into c
    from public.clients cl join public.gyms g on g.id = cl.gym_id
   where cl.id = p_client;
  if c.id is null or c.deleted_at is not null then return null; end if;
  -- без согласия на рассылки уходят только сервисные сообщения
  if not p_service and c.consent_marketing_at is null then return null; end if;
  -- ночью (22:00–09:00 по времени зала) не отправляем — переносим на 9:00
  v_local := v_send at time zone c.timezone;
  if extract(hour from v_local) >= 22 then
    v_send := ((v_local::date + 1) + time '09:00') at time zone c.timezone;
  elsif extract(hour from v_local) < 9 then
    v_send := (v_local::date + time '09:00') at time zone c.timezone;
  end if;
  insert into public.notifications_outbox (gym_id, client_id, kind, service, title, body, data, send_after, dedupe_key)
  values (c.gym_id, c.id, p_kind, p_service, p_title, p_body, p_data, v_send, p_dedupe)
  on conflict (dedupe_key) where dedupe_key is not null do nothing
  returning id into v_id;
  return v_id;
end $$;

-- Отметка «вернулся» по контактам из списка риска (FR-8.3)
create or replace function private.mark_returned(p_client uuid) returns void
language sql security definer set search_path = public as $$
  update public.risk_contacts set returned_at = now()
   where client_id = p_client and returned_at is null and contacted_at >= now() - interval '30 days'
$$;

create or replace function private.membership_json(m public.memberships) returns jsonb
language sql stable as $$
  select case when m.id is null then null else jsonb_build_object(
    'id', m.id, 'plan_name', m.plan_name, 'kind', m.kind, 'status', m.status,
    'starts_on', m.starts_on, 'ends_on', m.ends_on, 'visits_left', m.visits_left,
    'freeze_days_left', m.freeze_days_max - m.freeze_days_used) end
$$;

-- ---------------------------------------------------------------------------
-- 5.1 Регистрация зала
-- ---------------------------------------------------------------------------
-- Самостоятельная регистрация: создаёт зал с пробным периодом, вызывающий становится владельцем
create or replace function public.create_gym(p_name text, p_owner_name text, p_address text default null,
                                             p_timezone text default 'Europe/Moscow', p_phone text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
  v_email text;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  if exists (select 1 from public.staff where user_id = auth.uid() and role = 'owner' and active) then
    perform private.fail('GYM_EXISTS', 'У вас уже есть зал. Несколько залов в одном кабинете — после MVP');
  end if;
  perform now() at time zone p_timezone;   -- валидация часового пояса
  select email into v_email from auth.users where id = auth.uid();
  insert into public.gyms (name, address, timezone, phone)
  values (p_name, p_address, p_timezone, p_phone) returning id into v_gym;
  insert into public.staff (gym_id, user_id, email, role, full_name)
  values (v_gym, auth.uid(), coalesce(v_email, auth.uid()::text), 'owner', p_owner_name);
  return v_gym;
end $$;

-- ---------------------------------------------------------------------------
-- 5.3 Абонементы
-- ---------------------------------------------------------------------------
create or replace function private.create_membership(
  p_client uuid, p_plan uuid, p_starts_on date, p_status public.membership_status, p_renew_from uuid
) returns public.memberships
language plpgsql security definer set search_path = public as $$
declare
  c public.clients;
  pl public.membership_plans;
  m public.memberships;
  v_today date;
  v_starts date := p_starts_on;
  prev public.memberships;
  v_conflict public.memberships;
begin
  select * into c from public.clients where id = p_client and deleted_at is null;
  if c.id is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  select * into pl from public.membership_plans where id = p_plan and gym_id = c.gym_id;
  if pl.id is null or not pl.active then perform private.fail('PLAN_NOT_FOUND', 'Тариф не найден или отключён'); end if;
  v_today := private.gym_today(c.gym_id);

  if p_renew_from is not null then
    select * into prev from public.memberships where id = p_renew_from and client_id = c.id;
    if prev.id is null then perform private.fail('MEMBERSHIP_NOT_FOUND', 'Продлеваемый абонемент не найден'); end if;
    -- новый абонемент начинается после окончания текущего (FR-3.3)
    v_starts := greatest(prev.ends_on + 1, v_today);
    -- если после текущего уже есть продление — встаём за последним
    select greatest(v_starts, max(ends_on) + 1) into v_starts
      from public.memberships
     where client_id = c.id and status in ('active', 'frozen') and ends_on >= v_starts;
  else
    v_starts := coalesce(v_starts, v_today);
    if v_starts < v_today - 30 then
      perform private.fail('INVALID_DATE', 'Дата начала не может быть раньше чем 30 дней назад');
    end if;
  end if;

  if p_status in ('active', 'frozen') then
    select * into v_conflict from public.memberships
     where client_id = c.id and status in ('active', 'frozen')
       and daterange(starts_on, ends_on, '[]') && daterange(v_starts, v_starts + pl.duration_days - 1, '[]')
     order by ends_on desc limit 1;
    if v_conflict.id is not null then
      perform private.fail('MEMBERSHIP_OVERLAP',
        format('У клиента уже есть действующий абонемент до %s — оформите продление', private.fmt_date(v_conflict.ends_on)));
    end if;
  end if;

  insert into public.memberships (gym_id, client_id, plan_id, plan_name, kind, starts_on, ends_on, visits_left,
                                  freeze_days_max, status, price_paid, renewed_from_id, created_by)
  values (c.gym_id, c.id, pl.id, pl.name, pl.kind, v_starts, v_starts + pl.duration_days - 1,
          case when pl.kind = 'visits' then pl.visits_limit end,
          pl.freeze_days_max, p_status, pl.price, p_renew_from, auth.uid())
  returning * into m;
  return m;
end $$;

-- FR-3.2 / FR-3.3 Продажа и продление с оплатой наличными или картой через терминал зала
create or replace function public.sell_membership(
  p_client uuid, p_plan uuid, p_method public.payment_method,
  p_starts_on date default null, p_renew_from uuid default null, p_comment text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
  v_staff uuid;
  m public.memberships;
  v_payment uuid;
begin
  select gym_id into v_gym from public.clients where id = p_client and deleted_at is null;
  if v_gym is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  v_staff := private.require_staff(v_gym);
  if p_method = 'online' then
    perform private.fail('USE_ONLINE_PAYMENT', 'Онлайн-оплата оформляется через ссылку на оплату');
  end if;

  m := private.create_membership(p_client, p_plan, p_starts_on, 'active', p_renew_from);

  if m.price_paid > 0 then
    insert into public.payments (gym_id, client_id, membership_id, amount, method, status, staff_id, paid_at, description)
    values (v_gym, p_client, m.id, m.price_paid, p_method, 'succeeded', v_staff, now(),
            coalesce(p_comment, 'Абонемент «' || m.plan_name || '»'))
    returning id into v_payment;
  end if;

  perform private.mark_returned(p_client);
  return jsonb_build_object('membership', private.membership_json(m), 'payment_id', v_payment);
end $$;

-- FR-3.4 Заморозка в пределах лимита тарифа; дата окончания сдвигается автоматически
create or replace function public.freeze_membership(p_membership uuid, p_from date, p_to date, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  m public.memberships;
  v_days int := p_to - p_from + 1;
  v_today date;
  v_is_staff boolean;
  v_freeze uuid;
begin
  select * into m from public.memberships where id = p_membership for update;
  if m.id is null then perform private.fail('MEMBERSHIP_NOT_FOUND', 'Абонемент не найден'); end if;

  v_is_staff := private.is_staff(m.gym_id);
  if v_is_staff then
    perform private.require_staff(m.gym_id);
  elsif private.is_own_client(m.client_id) then
    if not private.gym_writable(m.gym_id) then
      perform private.fail('GYM_READ_ONLY', 'Зал временно не принимает изменения');
    end if;
    if coalesce((select (settings ->> 'allow_app_freeze')::boolean from public.gyms where id = m.gym_id), false) is not true then
      perform private.fail('FREEZE_NOT_ALLOWED', 'Зал не разрешает заморозку из приложения — обратитесь на ресепшен');
    end if;
  else
    perform private.fail('FORBIDDEN', 'Недостаточно прав для этого действия');
  end if;

  v_today := private.gym_today(m.gym_id);
  if m.status not in ('active', 'frozen') then
    perform private.fail('MEMBERSHIP_NOT_ACTIVE', 'Заморозить можно только действующий абонемент');
  end if;
  if p_to < p_from then perform private.fail('INVALID_DATE', 'Дата окончания заморозки раньше даты начала'); end if;
  if p_from < v_today then perform private.fail('INVALID_DATE', 'Заморозка не может начинаться в прошлом'); end if;
  if p_from < m.starts_on or p_from > m.ends_on then
    perform private.fail('INVALID_DATE', 'Заморозка должна начинаться в период действия абонемента');
  end if;
  if m.freeze_days_used + v_days > m.freeze_days_max then
    perform private.fail('FREEZE_LIMIT',
      format('Превышен лимит заморозки: доступно %s дн.', m.freeze_days_max - m.freeze_days_used));
  end if;
  if exists (select 1 from public.freezes where membership_id = m.id
               and daterange(from_date, to_date, '[]') && daterange(p_from, p_to, '[]')) then
    perform private.fail('FREEZE_OVERLAP', 'Период пересекается с уже оформленной заморозкой');
  end if;

  set constraints public.memberships_no_overlap deferred;
  -- сдвигаем уже купленные продления, чтобы абонементы не пересекались
  update public.memberships
     set starts_on = starts_on + v_days, ends_on = ends_on + v_days
   where client_id = m.client_id and id <> m.id
     and status in ('active', 'frozen', 'pending') and starts_on > m.ends_on;
  update public.memberships
     set ends_on = ends_on + v_days,
         freeze_days_used = freeze_days_used + v_days,
         status = case when p_from <= v_today then 'frozen'::public.membership_status else status end
   where id = m.id
  returning * into m;
  set constraints public.memberships_no_overlap immediate;

  insert into public.freezes (gym_id, membership_id, from_date, to_date, reason, created_by)
  values (m.gym_id, m.id, p_from, p_to, p_reason, auth.uid())
  returning id into v_freeze;

  return jsonb_build_object('freeze_id', v_freeze, 'membership', private.membership_json(m));
end $$;

-- Досрочное окончание заморозки: неиспользованные дни возвращаются в лимит
create or replace function public.end_freeze(p_freeze uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  f public.freezes;
  m public.memberships;
  v_today date;
  v_new_to date;
  v_return int;
begin
  select * into f from public.freezes where id = p_freeze for update;
  if f.id is null then perform private.fail('FREEZE_NOT_FOUND', 'Заморозка не найдена'); end if;
  perform private.require_staff(f.gym_id);
  select * into m from public.memberships where id = f.membership_id for update;
  v_today := private.gym_today(f.gym_id);
  if f.to_date < v_today then perform private.fail('FREEZE_FINISHED', 'Заморозка уже закончилась'); end if;

  set constraints public.memberships_no_overlap deferred;
  if f.from_date >= v_today then
    v_return := f.days;
    delete from public.freezes where id = f.id;
  else
    v_new_to := v_today - 1;
    v_return := f.to_date - v_new_to;
    update public.freezes set to_date = v_new_to where id = f.id;
  end if;
  update public.memberships
     set starts_on = starts_on - v_return, ends_on = ends_on - v_return
   where client_id = m.client_id and id <> m.id
     and status in ('active', 'frozen', 'pending') and starts_on > m.ends_on;
  update public.memberships
     set ends_on = ends_on - v_return,
         freeze_days_used = freeze_days_used - v_return,
         status = case when status = 'frozen' then 'active'::public.membership_status else status end
   where id = m.id
  returning * into m;
  set constraints public.memberships_no_overlap immediate;
  return jsonb_build_object('membership', private.membership_json(m), 'days_returned', v_return);
end $$;

-- Отмена абонемента (без возврата; возврат — refund_payment). FR-3.6
create or replace function public.cancel_membership(p_membership uuid, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  m public.memberships;
begin
  select * into m from public.memberships where id = p_membership for update;
  if m.id is null then perform private.fail('MEMBERSHIP_NOT_FOUND', 'Абонемент не найден'); end if;
  perform private.require_staff(m.gym_id, '{owner,admin}');
  if m.status in ('cancelled', 'expired') then
    perform private.fail('MEMBERSHIP_NOT_ACTIVE', 'Абонемент уже не действует');
  end if;
  update public.memberships set status = 'cancelled', cancelled_at = now() where id = m.id returning * into m;
  return jsonb_build_object('membership', private.membership_json(m));
end $$;

-- ---------------------------------------------------------------------------
-- 5.6 Оплаты: возвраты, онлайн-оплата
-- ---------------------------------------------------------------------------
-- FR-6.3 / FR-3.6 Возврат полной или частичной суммы.
-- Наличные и карта — возврат сразу; онлайн — строка-возврат в статусе pending,
-- Edge Function payments/refund проводит его в ЮKassa и подтверждает confirm_refund.
create or replace function public.refund_payment(p_payment uuid, p_amount bigint default null,
                                                 p_cancel_membership boolean default false, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  p public.payments;
  v_staff uuid;
  v_refunded bigint;
  v_amount bigint;
  v_refund uuid;
  v_status public.payment_status;
begin
  select * into p from public.payments where id = p_payment for update;
  if p.id is null or p.refund_of_id is not null then perform private.fail('PAYMENT_NOT_FOUND', 'Оплата не найдена'); end if;
  v_staff := private.require_staff(p.gym_id, '{owner,admin}');
  if p.status not in ('succeeded') then perform private.fail('PAYMENT_NOT_REFUNDABLE', 'Эту оплату нельзя вернуть'); end if;

  select coalesce(sum(amount), 0) into v_refunded
    from public.payments where refund_of_id = p.id and status in ('pending', 'refunded');
  v_amount := coalesce(p_amount, p.amount - v_refunded);
  if v_amount <= 0 or v_amount > p.amount - v_refunded then
    perform private.fail('REFUND_AMOUNT_INVALID',
      format('Сумма возврата должна быть от 0,01 до %s ₽', to_char((p.amount - v_refunded) / 100.0, 'FM999999990.00')));
  end if;
  if exists (select 1 from public.payments where refund_of_id = p.id and status = 'pending') then
    perform private.fail('REFUND_IN_PROGRESS', 'По этой оплате уже проводится возврат');
  end if;

  v_status := case when p.method = 'online' then 'pending' else 'refunded' end;
  insert into public.payments (gym_id, client_id, membership_id, amount, method, status, provider, staff_id,
                               refund_of_id, paid_at, description)
  values (p.gym_id, p.client_id, p.membership_id, v_amount, p.method, v_status, p.provider, v_staff,
          p.id, case when v_status = 'refunded' then now() end, coalesce(p_reason, 'Возврат'))
  returning id into v_refund;

  if v_status = 'refunded' and v_refunded + v_amount = p.amount then
    update public.payments set status = 'refunded' where id = p.id;
  end if;
  if p_cancel_membership and p.membership_id is not null then
    update public.memberships set status = 'cancelled', cancelled_at = now()
     where id = p.membership_id and status in ('active', 'frozen', 'pending');
  end if;

  return jsonb_build_object('refund_id', v_refund, 'amount', v_amount, 'status', v_status,
                            'needs_provider', v_status = 'pending', 'provider_payment_id', p.provider_payment_id);
end $$;

-- Подтверждение возврата от провайдера (только сервер)
create or replace function public.confirm_refund(p_refund uuid, p_succeeded boolean, p_provider_refund_id text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r public.payments;
  v_total bigint;
begin
  select * into r from public.payments where id = p_refund and refund_of_id is not null for update;
  if r.id is null then perform private.fail('PAYMENT_NOT_FOUND', 'Возврат не найден'); end if;
  if r.status <> 'pending' then return jsonb_build_object('status', r.status, 'idempotent', true); end if;
  if p_succeeded then
    update public.payments set status = 'refunded', paid_at = now(),
           provider_payment_id = coalesce(p_provider_refund_id, provider_payment_id)
     where id = r.id;
    select coalesce(sum(amount), 0) into v_total from public.payments
     where refund_of_id = r.refund_of_id and status = 'refunded';
    update public.payments set status = 'refunded'
     where id = r.refund_of_id and amount <= v_total;
  else
    update public.payments set status = 'failed' where id = r.id;
  end if;
  return jsonb_build_object('status', case when p_succeeded then 'refunded' else 'failed' end);
end $$;

-- FR-6.2 Начало онлайн-покупки: абонемент в статусе pending + платёж pending.
-- Вызывают: сотрудник (ссылка на оплату из кабинета) или сам клиент (приложение).
create or replace function public.start_online_purchase(
  p_plan uuid, p_client uuid default null, p_starts_on date default null, p_renew_from uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  pl public.membership_plans;
  v_client uuid := p_client;
  v_staff uuid;
  m public.memberships;
  v_payment uuid;
  c public.clients;
begin
  select * into pl from public.membership_plans where id = p_plan;
  if pl.id is null then perform private.fail('PLAN_NOT_FOUND', 'Тариф не найден'); end if;
  perform private.require_feature(pl.gym_id, 'online_payments');

  if private.is_staff(pl.gym_id) then
    v_staff := private.require_staff(pl.gym_id);
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
  else
    if not private.gym_writable(pl.gym_id) then
      perform private.fail('GYM_READ_ONLY', 'Зал временно не принимает оплаты');
    end if;
    if not pl.sold_online then perform private.fail('PLAN_NOT_FOR_SALE', 'Тариф не продаётся в приложении'); end if;
    select id into v_client from public.clients
     where gym_id = pl.gym_id and user_id = auth.uid() and deleted_at is null;
    if v_client is null then perform private.fail('CLIENT_NOT_FOUND', 'Вы ещё не клиент этого зала'); end if;
  end if;

  select * into c from public.clients where id = v_client and gym_id = pl.gym_id and deleted_at is null;
  if c.id is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  if pl.price <= 0 then perform private.fail('PLAN_FREE', 'Бесплатный тариф оформляется на ресепшене'); end if;

  -- Для продления в приложении берём последний абонемент клиента
  m := private.create_membership(c.id, pl.id, p_starts_on,
        'pending',
        coalesce(p_renew_from, (select id from public.memberships
                                  where client_id = c.id and status in ('active', 'frozen')
                                  order by ends_on desc limit 1)));

  insert into public.payments (gym_id, client_id, membership_id, amount, method, status, provider, staff_id, description)
  values (pl.gym_id, c.id, m.id, m.price_paid, 'online', 'pending', 'yookassa', v_staff,
          'Абонемент «' || m.plan_name || '»')
  returning id into v_payment;

  return jsonb_build_object('payment_id', v_payment, 'membership_id', m.id, 'gym_id', pl.gym_id,
                            'amount', m.price_paid, 'description', 'Абонемент «' || m.plan_name || '»',
                            'client', jsonb_build_object('id', c.id, 'full_name', c.full_name,
                                                         'phone', c.phone, 'email', c.email));
end $$;

-- Привязка платежа провайдера к нашему платежу (только сервер)
create or replace function public.attach_provider_payment(p_payment uuid, p_provider_payment_id text,
                                                          p_confirmation_url text default null)
returns void
language sql security definer set search_path = public as $$
  update public.payments
     set provider_payment_id = p_provider_payment_id, confirmation_url = p_confirmation_url
   where id = p_payment and status = 'pending'
$$;

-- FR-6.2 Обработка уведомления ЮKassa. Идемпотентно по provider_payment_id:
-- повторный webhook не создаёт второй абонемент (приёмка 5.6).
create or replace function public.confirm_online_payment(p_provider text, p_provider_payment_id text,
                                                         p_status text, p_receipt_url text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  p public.payments;
  m public.memberships;
  v_today date;
  v_len int;
  v_starts date;
  v_last date;
begin
  select * into p from public.payments
   where provider = p_provider and provider_payment_id = p_provider_payment_id and refund_of_id is null
   for update;
  if p.id is null then return jsonb_build_object('result', 'unknown_payment'); end if;

  if p_status = 'succeeded' then
    if p.status <> 'pending' then
      return jsonb_build_object('result', 'already_processed', 'status', p.status);
    end if;
    update public.payments set status = 'succeeded', paid_at = now(), receipt_url = coalesce(p_receipt_url, receipt_url)
     where id = p.id;

    select * into m from public.memberships where id = p.membership_id for update;
    if m.id is not null and m.status = 'pending' then
      v_today := private.gym_today(m.gym_id);
      v_len := m.ends_on - m.starts_on;
      v_starts := greatest(m.starts_on, v_today);
      -- пока клиент платил, мог появиться другой абонемент: встаём после него
      select max(ends_on) into v_last from public.memberships
       where client_id = m.client_id and id <> m.id and status in ('active', 'frozen') and ends_on >= v_starts;
      if v_last is not null then v_starts := v_last + 1; end if;
      update public.memberships
         set status = 'active', starts_on = v_starts, ends_on = v_starts + v_len
       where id = m.id;
      perform private.mark_returned(m.client_id);
    end if;
    return jsonb_build_object('result', 'activated', 'payment_id', p.id, 'membership_id', p.membership_id);

  elsif p_status in ('canceled', 'cancelled', 'failed') then
    if p.status <> 'pending' then
      return jsonb_build_object('result', 'already_processed', 'status', p.status);
    end if;
    update public.payments set status = 'failed' where id = p.id;
    update public.memberships set status = 'cancelled', cancelled_at = now()
     where id = p.membership_id and status = 'pending';
    return jsonb_build_object('result', 'cancelled', 'payment_id', p.id);
  end if;
  return jsonb_build_object('result', 'ignored');
end $$;

-- ---------------------------------------------------------------------------
-- 5.4 Посещения
-- ---------------------------------------------------------------------------
create or replace function private.checkin_result(p_ok boolean, p_code text, p_message text,
                                                  c public.clients, m public.memberships,
                                                  p_extra jsonb default '{}') returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'ok', p_ok, 'code', p_code, 'message', p_message,
    'client', case when c.id is null then null else jsonb_build_object(
       'id', c.id, 'full_name', c.full_name, 'photo_url', c.photo_url, 'phone', c.phone) end,
    'membership', private.membership_json(m)) || p_extra
$$;

-- Ядро отметки визита: проверка абонемента, защита от повторного скана, списание визита
create or replace function private.do_checkin(p_gym uuid, p_client uuid, p_method public.visit_method, p_staff uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c public.clients;
  m public.memberships;
  f public.freezes;
  v public.visits;
  v_today date := private.gym_today(p_gym);
  v_future public.memberships;
begin
  -- блокировка клиента сериализует одновременные сканы одного человека
  select * into c from public.clients where id = p_client and gym_id = p_gym and deleted_at is null for update;
  if c.id is null then
    return private.checkin_result(false, 'CLIENT_NOT_FOUND', 'Клиент не найден в этом зале', null, null);
  end if;

  select * into m from public.memberships
   where client_id = c.id and status in ('active', 'frozen') and starts_on <= v_today and ends_on >= v_today
   order by ends_on limit 1
   for update;

  -- FR-4.4: повторный скан за 10 минут не списывает второй визит
  select * into v from public.visits
   where client_id = c.id and checked_in_at > now() - interval '10 minutes'
   order by checked_in_at desc limit 1;
  if v.id is not null then
    return private.checkin_result(true, 'ALREADY_CHECKED_IN', 'Визит уже отмечен', c, m,
                                  jsonb_build_object('repeat', true, 'visit_id', v.id));
  end if;

  if m.id is null then
    select * into v_future from public.memberships
     where client_id = c.id and status in ('active', 'frozen') and starts_on > v_today
     order by starts_on limit 1;
    if v_future.id is not null then
      return private.checkin_result(false, 'MEMBERSHIP_NOT_STARTED',
        'Абонемент начнётся ' || private.fmt_date(v_future.starts_on), c, v_future);
    end if;
    return private.checkin_result(false, 'NO_ACTIVE_MEMBERSHIP', 'Нет действующего абонемента', c, null);
  end if;

  select * into f from public.freezes
   where membership_id = m.id and v_today between from_date and to_date limit 1;
  if f.id is not null then
    return private.checkin_result(false, 'MEMBERSHIP_FROZEN',
      'Абонемент заморожен до ' || private.fmt_date(f.to_date), c, m);
  end if;
  if m.kind = 'visits' and coalesce(m.visits_left, 0) <= 0 then
    return private.checkin_result(false, 'NO_VISITS_LEFT', 'Закончились визиты по абонементу', c, m);
  end if;

  -- закрываем незакрытые прошлые визиты
  update public.visits set checked_out_at = now() where client_id = c.id and checked_out_at is null;

  insert into public.visits (gym_id, client_id, membership_id, method, staff_id)
  values (p_gym, c.id, m.id, p_method, p_staff) returning * into v;

  if m.kind = 'visits' then
    update public.memberships set visits_left = visits_left - 1 where id = m.id returning * into m;
  end if;
  update public.clients set last_visit_at = v.checked_in_at where id = c.id;

  -- FR-5.5: визит закрывает запись на ближайшее занятие как «пришёл»
  update public.bookings b set status = 'attended'
    from public.schedule_items s
   where b.schedule_item_id = s.id and b.client_id = c.id and b.status = 'booked'
     and s.starts_at between now() - interval '60 minutes' and now() + interval '90 minutes';

  perform private.mark_returned(c.id);

  return private.checkin_result(true, 'OK', 'Проходите!', c, m,
                                jsonb_build_object('repeat', false, 'visit_id', v.id));
end $$;

-- FR-4.3 Ручная отметка визита
create or replace function public.checkin_manual(p_client uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
  v_staff uuid;
begin
  select gym_id into v_gym from public.clients where id = p_client;
  if v_gym is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  v_staff := private.require_staff(v_gym);
  return private.do_checkin(v_gym, p_client, 'manual', v_staff);
end $$;

-- Разбор и проверка динамического QR (раздел 6).
-- Формат: CORE1:<device_id>:<t>:<sig>, t = floor(unix_time / 30),
-- sig = первые 16 байт HMAC-SHA256(key = qr_secret (hex), msg = 'CORE1:<device_id>:<t>') в hex.
-- Код принимается, если t ∈ [t_now − 1, t_now + 1]: скриншот старше 60 секунд не проходит.
create or replace function private.verify_qr(p_payload text) returns jsonb
language plpgsql stable security definer set search_path = public, extensions as $$
declare
  parts text[];
  v_device uuid;
  v_t bigint;
  v_now_t bigint := floor(extract(epoch from now()) / 30);
  d public.client_devices;
  v_expected text;
begin
  parts := string_to_array(trim(p_payload), ':');
  if array_length(parts, 1) <> 4 or parts[1] <> 'CORE1'
     or parts[2] !~ '^[0-9a-fA-F-]{36}$' or parts[3] !~ '^\d{1,12}$' or parts[4] !~ '^[0-9a-f]{32}$' then
    return jsonb_build_object('ok', false, 'code', 'QR_INVALID', 'message', 'Это не QR-пропуск core.');
  end if;
  v_device := parts[2]::uuid;
  v_t := parts[3]::bigint;

  select * into d from public.client_devices where id = v_device;
  if d.id is null or d.revoked_at is not null then
    return jsonb_build_object('ok', false, 'code', 'QR_INVALID', 'message', 'Пропуск недействителен — обновите приложение');
  end if;

  v_expected := left(encode(extensions.hmac(convert_to(parts[1] || ':' || parts[2] || ':' || parts[3], 'UTF8'),
                                            decode(d.qr_secret, 'hex'), 'sha256'), 'hex'), 32);
  if v_expected <> parts[4] then
    return jsonb_build_object('ok', false, 'code', 'QR_INVALID', 'message', 'Подпись QR не совпадает');
  end if;
  if v_t < v_now_t - 1 or v_t > v_now_t + 1 then
    return jsonb_build_object('ok', false, 'code', 'QR_EXPIRED', 'message', 'QR устарел — попросите открыть пропуск заново');
  end if;
  return jsonb_build_object('ok', true, 'user_id', d.user_id, 'device_id', d.id);
end $$;

-- FR-4.1 / FR-4.2 Отметка визита по QR (ресепшен)
create or replace function public.checkin_qr(p_gym uuid, p_payload text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_staff uuid;
  v_check jsonb;
  v_client uuid;
begin
  v_staff := private.require_staff(p_gym);
  v_check := private.verify_qr(p_payload);
  if not (v_check ->> 'ok')::boolean then
    return v_check || jsonb_build_object('client', null, 'membership', null);
  end if;
  select id into v_client from public.clients
   where gym_id = p_gym and user_id = (v_check ->> 'user_id')::uuid and deleted_at is null;
  if v_client is null then
    return jsonb_build_object('ok', false, 'code', 'CLIENT_NOT_FOUND',
                              'message', 'Владелец пропуска не клиент этого зала', 'client', null, 'membership', null);
  end if;
  return private.do_checkin(p_gym, v_client, 'qr', v_staff);
end $$;

-- Выход из зала вручную
create or replace function public.checkout_visit(p_visit uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
begin
  select gym_id into v_gym from public.visits where id = p_visit;
  if v_gym is null then perform private.fail('VISIT_NOT_FOUND', 'Визит не найден'); end if;
  perform private.require_staff(v_gym);
  update public.visits set checked_out_at = now() where id = p_visit and checked_out_at is null;
end $$;

-- ---------------------------------------------------------------------------
-- 5.5 Расписание и бронь
-- ---------------------------------------------------------------------------
-- FR-5.2 Разовое или повторяющееся занятие. Время — локальное время зала.
create or replace function public.create_schedule_series(
  p_gym uuid, p_title text, p_starts_local timestamp, p_duration_min int,
  p_capacity int default 10, p_kind public.schedule_kind default 'class', p_zone uuid default null,
  p_trainer text default null, p_weekdays int[] default null, p_until date default null,
  p_description text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_tz text;
  v_series uuid;
  v_rule text;
  v_day date;
  v_count int := 0;
  v_until date;
begin
  perform private.require_staff(p_gym, '{owner,admin}');
  perform private.require_feature(p_gym, 'schedule');
  if p_duration_min <= 0 then perform private.fail('INVALID_DURATION', 'Длительность должна быть больше нуля'); end if;
  select timezone into v_tz from public.gyms where id = p_gym;

  if p_weekdays is null or cardinality(p_weekdays) = 0 then
    insert into public.schedule_items (gym_id, kind, title, description, zone_id, trainer_name, starts_at, ends_at, capacity)
    values (p_gym, p_kind, p_title, p_description, p_zone, p_trainer,
            p_starts_local at time zone v_tz,
            (p_starts_local + make_interval(mins => p_duration_min)) at time zone v_tz,
            p_capacity);
    return jsonb_build_object('created', 1, 'series_id', null);
  end if;

  v_until := least(coalesce(p_until, p_starts_local::date + 83), p_starts_local::date + 365);
  v_series := gen_random_uuid();
  v_rule := 'FREQ=WEEKLY;BYDAY=' ||
            array_to_string(array(select (array['MO','TU','WE','TH','FR','SA','SU'])[d]
                                    from unnest(p_weekdays) d order by d), ',') ||
            ';UNTIL=' || to_char(v_until, 'YYYYMMDD');
  for v_day in select generate_series(p_starts_local::date, v_until, interval '1 day')::date loop
    if extract(isodow from v_day)::int = any (p_weekdays) then
      insert into public.schedule_items (gym_id, kind, title, description, zone_id, trainer_name, starts_at, ends_at,
                                         capacity, recurrence_rule, series_id)
      values (p_gym, p_kind, p_title, p_description, p_zone, p_trainer,
              (v_day + p_starts_local::time) at time zone v_tz,
              (v_day + p_starts_local::time + make_interval(mins => p_duration_min)) at time zone v_tz,
              p_capacity, v_rule, v_series);
      v_count := v_count + 1;
    end if;
  end loop;
  return jsonb_build_object('created', v_count, 'series_id', v_series, 'rule', v_rule);
end $$;

-- FR-5.3 Запись клиента: с ресепшена (p_client) или из приложения (свой клиент).
-- Блокировка строки занятия гарантирует: на последнее место проходит ровно один.
create or replace function public.book_class(p_item uuid, p_client uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s public.schedule_items;
  v_client uuid := p_client;
  v_channel public.booking_channel;
  v_taken int;
  b public.bookings;
  v_tz text;
  v_date date;
  c public.clients;
begin
  select * into s from public.schedule_items where id = p_item for update;
  if s.id is null then perform private.fail('CLASS_NOT_FOUND', 'Занятие не найдено'); end if;
  perform private.require_feature(s.gym_id, 'schedule');

  if private.is_staff(s.gym_id) then
    perform private.require_staff(s.gym_id);
    v_channel := 'staff';
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
  else
    v_channel := 'app';
    if not private.gym_writable(s.gym_id) then perform private.fail('GYM_READ_ONLY', 'Запись временно недоступна'); end if;
    select id into v_client from public.clients
     where gym_id = s.gym_id and user_id = auth.uid() and deleted_at is null;
    if v_client is null then perform private.fail('CLIENT_NOT_FOUND', 'Вы ещё не клиент этого зала'); end if;
  end if;

  select * into c from public.clients where id = v_client and gym_id = s.gym_id and deleted_at is null;
  if c.id is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  if s.cancelled then perform private.fail('CLASS_CANCELLED', 'Занятие отменено'); end if;
  if s.starts_at <= now() then perform private.fail('CLASS_STARTED', 'Занятие уже началось'); end if;

  -- из приложения записаться можно только с абонементом, действующим в день занятия
  if v_channel = 'app' then
    select timezone into v_tz from public.gyms where id = s.gym_id;
    v_date := (s.starts_at at time zone v_tz)::date;
    if not exists (
      select 1 from public.memberships m
       where m.client_id = c.id and m.status in ('active', 'frozen')
         and v_date between m.starts_on and m.ends_on
         and not exists (select 1 from public.freezes f where f.membership_id = m.id and v_date between f.from_date and f.to_date)
    ) then
      perform private.fail('NO_ACTIVE_MEMBERSHIP', 'Нет действующего абонемента на дату занятия');
    end if;
  end if;

  select * into b from public.bookings where schedule_item_id = s.id and client_id = c.id;
  if b.id is not null and b.status in ('booked', 'attended') then
    perform private.fail('ALREADY_BOOKED', 'Клиент уже записан на это занятие');
  end if;

  select count(*) into v_taken from public.bookings
   where schedule_item_id = s.id and status in ('booked', 'attended');
  if v_taken >= s.capacity then perform private.fail('CLASS_FULL', 'Свободных мест нет'); end if;

  if b.id is not null then
    update public.bookings set status = 'booked', channel = v_channel, cancelled_at = null
     where id = b.id returning * into b;
  else
    insert into public.bookings (gym_id, schedule_item_id, client_id, status, channel)
    values (s.gym_id, s.id, c.id, 'booked', v_channel) returning * into b;
  end if;

  select timezone into v_tz from public.gyms where id = s.gym_id;
  perform private.enqueue_notification(c.id, 'booking_confirmed', true, 'Вы записаны',
    s.title || ', ' || to_char(s.starts_at at time zone v_tz, 'DD.MM в HH24:MI'),
    jsonb_build_object('schedule_item_id', s.id, 'booking_id', b.id), now(), null);
  if s.starts_at - interval '2 hours' > now() then
    perform private.enqueue_notification(c.id, 'class_reminder', true, 'Скоро занятие',
      s.title || ' начнётся в ' || to_char(s.starts_at at time zone v_tz, 'HH24:MI'),
      jsonb_build_object('schedule_item_id', s.id, 'booking_id', b.id),
      s.starts_at - interval '2 hours', 'reminder:' || b.id || ':' || extract(epoch from s.starts_at)::bigint);
  end if;

  return jsonb_build_object('booking_id', b.id, 'spots_left', s.capacity - v_taken - 1);
end $$;

-- FR-5.4 Отмена записи: клиент — не позднее чем за N часов, сотрудник — в любое время
create or replace function public.cancel_booking(p_booking uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  b public.bookings;
  s public.schedule_items;
  v_hours int;
  v_tz text;
begin
  select * into b from public.bookings where id = p_booking for update;
  if b.id is null then perform private.fail('BOOKING_NOT_FOUND', 'Запись не найдена'); end if;
  select * into s from public.schedule_items where id = b.schedule_item_id for update;
  select coalesce((settings ->> 'booking_cancel_hours')::int, 2), timezone into v_hours, v_tz
    from public.gyms where id = b.gym_id;

  if private.is_staff(b.gym_id) then
    perform private.require_staff(b.gym_id);
  elsif private.is_own_client(b.client_id) then
    if now() > s.starts_at - make_interval(hours => v_hours) then
      perform private.fail('CANCEL_TOO_LATE', format('Отменить запись можно не позднее чем за %s ч до начала', v_hours));
    end if;
  else
    perform private.fail('FORBIDDEN', 'Недостаточно прав для этого действия');
  end if;
  if b.status <> 'booked' then perform private.fail('BOOKING_NOT_ACTIVE', 'Запись уже отменена или закрыта'); end if;

  update public.bookings set status = 'cancelled', cancelled_at = now() where id = b.id;
  update public.notifications_outbox set status = 'skipped', last_error = 'booking cancelled'
   where kind = 'class_reminder' and status = 'queued' and data ->> 'booking_id' = b.id::text;
  perform private.enqueue_notification(b.client_id, 'booking_cancelled', true, 'Запись отменена',
    s.title || ', ' || to_char(s.starts_at at time zone v_tz, 'DD.MM в HH24:MI'),
    jsonb_build_object('schedule_item_id', s.id, 'booking_id', b.id));
  return jsonb_build_object('booking_id', b.id, 'status', 'cancelled');
end $$;

-- FR-5.4 Отмена занятия залом с уведомлением записавшихся
create or replace function public.cancel_class(p_item uuid, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s public.schedule_items;
  r record;
  v_tz text;
  v_n int := 0;
begin
  select * into s from public.schedule_items where id = p_item for update;
  if s.id is null then perform private.fail('CLASS_NOT_FOUND', 'Занятие не найдено'); end if;
  perform private.require_staff(s.gym_id, '{owner,admin}');
  if s.cancelled then return jsonb_build_object('notified', 0); end if;
  select timezone into v_tz from public.gyms where id = s.gym_id;
  update public.schedule_items set cancelled = true, cancelled_reason = p_reason where id = s.id;
  for r in update public.bookings set status = 'cancelled', cancelled_at = now()
            where schedule_item_id = s.id and status = 'booked' returning id, client_id loop
    v_n := v_n + 1;
    perform private.enqueue_notification(r.client_id, 'class_cancelled', true, 'Занятие отменено',
      s.title || ', ' || to_char(s.starts_at at time zone v_tz, 'DD.MM в HH24:MI') ||
      coalesce('. ' || p_reason, ''),
      jsonb_build_object('schedule_item_id', s.id, 'booking_id', r.id));
  end loop;
  update public.notifications_outbox set status = 'skipped', last_error = 'class cancelled'
   where kind = 'class_reminder' and status = 'queued' and data ->> 'schedule_item_id' = s.id::text;
  return jsonb_build_object('notified', v_n);
end $$;

-- FR-5.5 Отметка «пришёл / не пришёл»
create or replace function public.mark_booking(p_booking uuid, p_status public.booking_status) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
begin
  if p_status not in ('attended', 'no_show', 'booked') then
    perform private.fail('INVALID_STATUS', 'Недопустимый статус');
  end if;
  select gym_id into v_gym from public.bookings where id = p_booking;
  if v_gym is null then perform private.fail('BOOKING_NOT_FOUND', 'Запись не найдена'); end if;
  perform private.require_staff(v_gym);
  update public.bookings set status = p_status where id = p_booking and status <> 'cancelled';
end $$;

-- ---------------------------------------------------------------------------
-- 5.2 Клиенты: импорт и обезличивание
-- ---------------------------------------------------------------------------
-- FR-2.4 Импорт клиентов и действующих абонементов. Повторный импорт обновляет, а не дублирует.
-- p_rows — массив объектов {row, full_name, phone, email, birth_date (YYYY-MM-DD), gender, source, tags, note,
--                           plan_name, starts_on, ends_on, visits_left}. Ошибочные строки не ломают остальные.
create or replace function public.import_clients(p_gym uuid, p_rows jsonb, p_consent boolean default false)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r jsonb;
  v_row int;
  v_phone text;
  v_client uuid;
  v_created int := 0;
  v_updated int := 0;
  v_memberships int := 0;
  v_errors jsonb := '[]';
  v_today date := private.gym_today(p_gym);
  pl public.membership_plans;
  v_starts date;
  v_ends date;
  v_kind public.plan_kind;
  v_inserted boolean;
begin
  perform private.require_staff(p_gym, '{owner,admin}');
  perform private.require_feature(p_gym, 'import');
  if jsonb_array_length(p_rows) > 5000 then
    perform private.fail('IMPORT_TOO_LARGE', 'За один раз можно загрузить до 5 000 строк');
  end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_row := coalesce((r ->> 'row')::int, v_created + v_updated + jsonb_array_length(v_errors) + 1);
    begin
      if coalesce(trim(r ->> 'full_name'), '') = '' then
        raise exception 'Не указано ФИО';
      end if;
      v_phone := public.normalize_phone(r ->> 'phone');
      if v_phone is null then
        raise exception 'Некорректный телефон: %', coalesce(r ->> 'phone', 'пусто');
      end if;

      insert into public.clients (gym_id, full_name, phone, email, birth_date, gender, source, tags, note,
                                  consent_pd_at, consent_pd_text)
      values (p_gym, r ->> 'full_name', v_phone, nullif(r ->> 'email', ''),
              nullif(r ->> 'birth_date', '')::date,
              nullif(r ->> 'gender', ''),
              coalesce(nullif(r ->> 'source', ''), 'импорт'),
              coalesce(array(select jsonb_array_elements_text(r -> 'tags')), '{}'),
              nullif(r ->> 'note', ''),
              case when p_consent then now() end,
              case when p_consent then 'Согласие получено залом до переноса в core. (импорт)' end)
      on conflict (gym_id, phone) where deleted_at is null do update
        set full_name  = excluded.full_name,
            email      = coalesce(excluded.email, clients.email),
            birth_date = coalesce(excluded.birth_date, clients.birth_date),
            gender     = coalesce(excluded.gender, clients.gender),
            tags       = case when cardinality(excluded.tags) > 0 then excluded.tags else clients.tags end,
            note       = coalesce(excluded.note, clients.note),
            consent_pd_at   = coalesce(clients.consent_pd_at, excluded.consent_pd_at),
            consent_pd_text = coalesce(clients.consent_pd_text, excluded.consent_pd_text)
      returning id, (xmax = 0) into v_client, v_inserted;
      if v_inserted then v_created := v_created + 1; else v_updated := v_updated + 1; end if;

      -- действующий абонемент (если указан)
      if nullif(r ->> 'ends_on', '') is not null then
        v_ends := (r ->> 'ends_on')::date;
        v_starts := coalesce(nullif(r ->> 'starts_on', '')::date, v_ends - 29);
        if v_ends < v_starts then raise exception 'Дата окончания абонемента раньше даты начала'; end if;
        pl := null;
        if nullif(r ->> 'plan_name', '') is not null then
          select * into pl from public.membership_plans
           where gym_id = p_gym and lower(name) = lower(trim(r ->> 'plan_name')) limit 1;
        end if;
        v_kind := coalesce(pl.kind, case when nullif(r ->> 'visits_left', '') is not null then 'visits' else 'period' end::public.plan_kind);
        if not exists (select 1 from public.memberships
                        where client_id = v_client and starts_on = v_starts and ends_on = v_ends
                          and status <> 'cancelled') then
          insert into public.memberships (gym_id, client_id, plan_id, plan_name, kind, starts_on, ends_on, visits_left,
                                          freeze_days_max, status, price_paid, imported, created_by)
          values (p_gym, v_client, pl.id,
                  coalesce(pl.name, nullif(trim(r ->> 'plan_name'), ''), 'Абонемент (импорт)'),
                  v_kind, v_starts, v_ends,
                  case when v_kind = 'visits' then coalesce(nullif(r ->> 'visits_left', '')::int, pl.visits_limit, 0) end,
                  coalesce(pl.freeze_days_max, 0),
                  case when v_ends < v_today then 'expired' else 'active' end::public.membership_status,
                  0, true, auth.uid());
          v_memberships := v_memberships + 1;
        end if;
      end if;
    exception
      when exclusion_violation then
        v_errors := v_errors || jsonb_build_object('row', v_row, 'error', 'Абонемент пересекается с уже существующим');
      when others then
        v_errors := v_errors || jsonb_build_object('row', v_row, 'error',
          case sqlstate
            when '22007' then 'Некорректная дата'
            when '22008' then 'Некорректная дата'
            when '22P02' then 'Некорректное значение'
            when '23514' then 'Недопустимое значение поля (проверьте пол и даты)'
            else sqlerrm end);
    end;
  end loop;

  return jsonb_build_object('created', v_created, 'updated', v_updated, 'memberships', v_memberships,
                            'errors', v_errors, 'total', jsonb_array_length(p_rows));
end $$;

-- FR-2.6 Удаление клиента по запросу: обезличивание, оплаты сохраняются для бухгалтерии
create or replace function private.anonymize_client_row(p_client uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.clients
     set full_name = 'Клиент удалён', phone = null, email = null, birth_date = null, gender = null,
         note = null, tags = '{}', photo_url = null, user_id = null,
         consent_marketing_at = null, deleted_at = coalesce(deleted_at, now())
   where id = p_client;
  update public.bookings b set status = 'cancelled', cancelled_at = now()
    from public.schedule_items s
   where b.schedule_item_id = s.id and b.client_id = p_client and b.status = 'booked' and s.starts_at > now();
  update public.risk_contacts set note = null where client_id = p_client;
  delete from public.notifications_outbox where client_id = p_client and status = 'queued';
  update public.client_devices set client_id = null where client_id = p_client;
end $$;

create or replace function public.anonymize_client(p_client uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
begin
  select gym_id into v_gym from public.clients where id = p_client and deleted_at is null;
  if v_gym is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  perform private.require_staff(v_gym, '{owner,admin}', false);
  perform private.anonymize_client_row(p_client);
end $$;

-- ---------------------------------------------------------------------------
-- 5.8 «В зоне риска»: отметка контакта
-- ---------------------------------------------------------------------------
create or replace function public.mark_contacted(p_client uuid, p_reason text, p_channel text,
                                                 p_note text default null, p_push_text text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  c public.clients;
  v_staff uuid;
  v_id uuid;
  v_gym_name text;
begin
  select * into c from public.clients where id = p_client and deleted_at is null;
  if c.id is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  v_staff := private.require_staff(c.gym_id);
  if p_channel = 'push' then
    if c.user_id is null then perform private.fail('CLIENT_NOT_IN_APP', 'Клиент не подключён к приложению'); end if;
    if c.consent_marketing_at is null then
      perform private.fail('NO_MARKETING_CONSENT', 'Клиент не давал согласия на рассылки');
    end if;
    select name into v_gym_name from public.gyms where id = c.gym_id;
    perform private.enqueue_notification(c.id, 'risk_push', false, v_gym_name,
      coalesce(p_push_text, 'Давно не виделись! Ждём вас на тренировке'), '{}'::jsonb, now(), null);
  end if;
  insert into public.risk_contacts (gym_id, client_id, reason, channel, note, staff_id)
  values (c.gym_id, c.id, p_reason, p_channel, p_note, v_staff)
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- Раздел 6: приложение клиента
-- ---------------------------------------------------------------------------
-- POST /v1/link — привязать аккаунт к клиентам залов по номеру телефона
create or replace function public.link_account() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_phone text;
  v_result jsonb;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  select public.normalize_phone(phone) into v_phone from auth.users where id = auth.uid();
  if v_phone is null then perform private.fail('PHONE_REQUIRED', 'В аккаунте не указан номер телефона'); end if;

  update public.clients set user_id = auth.uid()
   where phone = v_phone and deleted_at is null and user_id is null;

  select coalesce(jsonb_agg(jsonb_build_object('client_id', c.id, 'gym_id', g.id, 'gym_name', g.name,
                                               'full_name', c.full_name) order by g.name), '[]')
    into v_result
    from public.clients c join public.gyms g on g.id = c.gym_id
   where c.user_id = auth.uid() and c.deleted_at is null;
  return jsonb_build_object('phone', v_phone, 'clients', v_result);
end $$;

-- Клиент без записи в зале выбирает зал в приложении: создаётся клиент с источником «приложение core.»
create or replace function public.join_gym(p_gym uuid, p_full_name text, p_marketing_consent boolean default false)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_phone text;
  v_id uuid;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  if not private.gym_writable(p_gym) then perform private.fail('GYM_READ_ONLY', 'Зал временно не принимает новых клиентов'); end if;
  select public.normalize_phone(phone) into v_phone from auth.users where id = auth.uid();
  if v_phone is null then perform private.fail('PHONE_REQUIRED', 'В аккаунте не указан номер телефона'); end if;
  select id into v_id from public.clients where gym_id = p_gym and phone = v_phone and deleted_at is null;
  if v_id is not null then
    update public.clients set user_id = auth.uid() where id = v_id and user_id is null;
    return v_id;
  end if;
  insert into public.clients (gym_id, user_id, full_name, phone, source, consent_pd_at, consent_pd_text,
                              consent_marketing_at, consent_marketing_text)
  values (p_gym, auth.uid(), p_full_name, v_phone, 'приложение core.', now(),
          'Согласие на обработку персональных данных дано в приложении core.',
          case when p_marketing_consent then now() end,
          case when p_marketing_consent then 'Согласие на рассылки дано в приложении core.' end)
  returning id into v_id;
  return v_id;
end $$;

-- POST /v1/devices — регистрация устройства: push-токен и секрет QR.
-- При регистрации нового устройства секреты остальных устройств отзываются.
create or replace function public.register_device(p_platform text, p_push_token text default null,
                                                  p_device_id uuid default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  d public.client_devices;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  if p_device_id is not null then
    update public.client_devices set push_token = coalesce(p_push_token, push_token)
     where id = p_device_id and user_id = auth.uid() and revoked_at is null
    returning * into d;
  end if;
  if d.id is null then
    update public.client_devices set revoked_at = now(), push_token = null
     where user_id = auth.uid() and revoked_at is null;
    insert into public.client_devices (user_id, client_id, platform, push_token)
    values (auth.uid(),
            (select id from public.clients where user_id = auth.uid() and deleted_at is null order by created_at limit 1),
            p_platform, p_push_token)
    returning * into d;
  end if;
  return jsonb_build_object('device_id', d.id, 'qr_secret', d.qr_secret, 'qr_period_seconds', 30, 'qr_prefix', 'CORE1');
end $$;

-- DELETE /v1/me — запрос на удаление аккаунта и данных: обезличиваем записи клиента во всех залах
create or replace function public.request_account_deletion() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r record;
  v_n int := 0;
begin
  if auth.uid() is null then perform private.fail('UNAUTHORIZED', 'Требуется вход'); end if;
  for r in select id from public.clients where user_id = auth.uid() and deleted_at is null loop
    perform private.anonymize_client_row(r.id);
    v_n := v_n + 1;
  end loop;
  update public.client_devices set revoked_at = now(), push_token = null where user_id = auth.uid();
  return jsonb_build_object('anonymized_clients', v_n);
end $$;

-- ---------------------------------------------------------------------------
-- Фоновые задания (FR-3.5, FR-4.5, FR-9.2)
-- ---------------------------------------------------------------------------
create or replace function public.run_maintenance() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_expired int;
  v_frozen int;
  v_unfrozen int;
  v_checkout int;
  v_abandoned int;
  v_reminders int := 0;
  r record;
begin
  -- истёкшие абонементы → expired
  update public.memberships m set status = 'expired'
    from public.gyms g
   where g.id = m.gym_id and m.status in ('active', 'frozen')
     and m.ends_on < (now() at time zone g.timezone)::date;
  get diagnostics v_expired = row_count;

  -- статус заморозки по датам
  update public.memberships m set status = 'frozen'
    from public.gyms g
   where g.id = m.gym_id and m.status = 'active'
     and exists (select 1 from public.freezes f where f.membership_id = m.id
                   and (now() at time zone g.timezone)::date between f.from_date and f.to_date);
  get diagnostics v_frozen = row_count;
  update public.memberships m set status = 'active'
    from public.gyms g
   where g.id = m.gym_id and m.status = 'frozen'
     and not exists (select 1 from public.freezes f where f.membership_id = m.id
                       and (now() at time zone g.timezone)::date between f.from_date and f.to_date);
  get diagnostics v_unfrozen = row_count;

  -- FR-4.5 автоматический выход через настраиваемое время
  update public.visits v
     set checked_out_at = v.checked_in_at + make_interval(hours => coalesce((g.settings ->> 'auto_checkout_hours')::int, 3))
    from public.gyms g
   where g.id = v.gym_id and v.checked_out_at is null
     and v.checked_in_at < now() - make_interval(hours => coalesce((g.settings ->> 'auto_checkout_hours')::int, 3));
  get diagnostics v_checkout = row_count;

  -- брошенные онлайн-оплаты (старше суток)
  with p as (
    update public.payments set status = 'failed'
     where method = 'online' and status = 'pending' and refund_of_id is null
       and created_at < now() - interval '24 hours'
    returning membership_id
  )
  update public.memberships m set status = 'cancelled', cancelled_at = now()
    from p where m.id = p.membership_id and m.status = 'pending';
  get diagnostics v_abandoned = row_count;

  -- FR-9.2 напоминания об окончании абонемента за 7 и 1 день (если нет продления)
  for r in
    select m.id, m.client_id, m.ends_on, g.name gym_name,
           m.ends_on - (now() at time zone g.timezone)::date as days_left
      from public.memberships m join public.gyms g on g.id = m.gym_id
     where m.status in ('active', 'frozen')
       and m.ends_on - (now() at time zone g.timezone)::date in (7, 1)
       and not exists (select 1 from public.memberships n
                        where n.client_id = m.client_id and n.id <> m.id
                          and n.status in ('active', 'frozen') and n.starts_on > m.ends_on)
  loop
    if private.enqueue_notification(r.client_id, 'membership_expiring', false,
         'Абонемент заканчивается',
         case when r.days_left = 1 then 'Ваш абонемент в ' || r.gym_name || ' заканчивается завтра. Продлите в приложении.'
              else 'Ваш абонемент в ' || r.gym_name || ' заканчивается ' || private.fmt_date(r.ends_on) || '. Продлите в приложении.' end,
         jsonb_build_object('membership_id', r.id, 'action', 'renew'), now(),
         'expiring:' || r.id || ':' || r.days_left) is not null then
      v_reminders := v_reminders + 1;
    end if;
  end loop;

  return jsonb_build_object('expired', v_expired, 'frozen', v_frozen, 'unfrozen', v_unfrozen,
                            'auto_checkout', v_checkout, 'abandoned_payments', v_abandoned,
                            'expiring_reminders', v_reminders);
end $$;

-- Очередь уведомлений для Edge Function notify: забрать пачку (без двойной отправки
-- при параллельных воркерах) и отметить результат
create or replace function public.claim_notifications(p_limit int default 50) returns setof jsonb
language sql security definer set search_path = public as $$
  with picked as (
    select id from public.notifications_outbox
     where status = 'queued' and send_after <= now()
     order by send_after
     limit p_limit
     for update skip locked
  ), upd as (
    update public.notifications_outbox n
       set attempts = n.attempts + 1,
           send_after = now() + make_interval(mins => power(2, least(n.attempts + 1, 8))::int)  -- повтор, если воркер упадёт
      from picked where n.id = picked.id
    returning n.*
  )
  select jsonb_build_object(
           'id', u.id, 'kind', u.kind, 'service', u.service, 'title', u.title, 'body', u.body, 'data', u.data,
           'attempts', u.attempts,
           'client', jsonb_build_object('id', c.id, 'user_id', c.user_id, 'phone', c.phone, 'email', c.email,
                                        'marketing_ok', c.consent_marketing_at is not null, 'deleted', c.deleted_at is not null),
           'gym', jsonb_build_object('id', g.id, 'name', g.name, 'timezone', g.timezone,
                                     'fallback', coalesce(g.settings ->> 'notify_fallback', 'sms')),
           'push_tokens', coalesce((select jsonb_agg(d.push_token) from public.client_devices d
                                     where d.user_id = c.user_id and d.revoked_at is null and d.push_token is not null), '[]'))
    from upd u join public.clients c on c.id = u.client_id join public.gyms g on g.id = u.gym_id
$$;

create or replace function public.complete_notification(p_id uuid, p_status text, p_channel text default null,
                                                        p_error text default null) returns void
language sql security definer set search_path = public as $$
  update public.notifications_outbox
     set status = case when p_status = 'failed' and attempts < 5 then 'queued' else p_status end,
         channel = coalesce(p_channel, channel),
         last_error = p_error,
         sent_at = case when p_status = 'sent' then now() else sent_at end
   where id = p_id
$$;

-- ---------------------------------------------------------------------------
-- 5.10 Управление залами (команда core.)
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_gyms() returns table (
  id uuid, name text, address text, core_plan public.core_plan, trial_until date, paid_until date,
  features jsonb, read_only boolean, clients_count bigint, visits_week bigint, owner_email text, created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
begin
  if not private.is_platform_admin() then perform private.fail('FORBIDDEN', 'Только для команды core.'); end if;
  return query
    select g.id, g.name, g.address, g.core_plan, g.trial_until, g.paid_until, public.gym_features(g.id),
           not private.gym_writable(g.id),
           (select count(*) from public.clients c where c.gym_id = g.id and c.deleted_at is null),
           (select count(*) from public.visits v where v.gym_id = g.id and v.checked_in_at > now() - interval '7 days'),
           (select s.email from public.staff s where s.gym_id = g.id and s.role = 'owner' order by s.created_at limit 1),
           g.created_at
      from public.gyms g
     order by g.created_at desc;
end $$;

create or replace function public.admin_update_gym(p_gym uuid, p_core_plan public.core_plan default null,
                                                   p_trial_until date default null, p_paid_until date default null,
                                                   p_features jsonb default null, p_clear_paid boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not private.is_platform_admin() then perform private.fail('FORBIDDEN', 'Только для команды core.'); end if;
  update public.gyms
     set core_plan   = coalesce(p_core_plan, core_plan),
         trial_until = coalesce(p_trial_until, trial_until),
         paid_until  = case when p_clear_paid then null else coalesce(p_paid_until, paid_until) end,
         features    = coalesce(p_features, features)
   where id = p_gym;
end $$;

-- Поиск пользователя по email для приглашения сотрудника, который уже зарегистрирован (только сервер)
create or replace function public.admin_find_user(p_email text) returns uuid
language sql stable security definer set search_path = public as $$
  select id from auth.users where lower(email) = lower(trim(p_email)) limit 1
$$;

-- ---------------------------------------------------------------------------
-- Права на функции
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
-- только сервер (Edge Functions с service key, cron)
revoke execute on function public.confirm_online_payment(text, text, text, text) from authenticated;
revoke execute on function public.attach_provider_payment(uuid, text, text) from authenticated;
revoke execute on function public.confirm_refund(uuid, boolean, text) from authenticated;
revoke execute on function public.run_maintenance() from authenticated;
revoke execute on function public.claim_notifications(int) from authenticated;
revoke execute on function public.complete_notification(uuid, text, text, text) from authenticated;
revoke execute on function public.admin_find_user(text) from authenticated;
-- внутренние функции
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated, service_role;
