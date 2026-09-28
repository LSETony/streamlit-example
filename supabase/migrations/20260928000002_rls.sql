-- core. MVP — права доступа (раздел 2) и изоляция залов через Row Level Security (раздел 3, 7)
--
-- Принципы:
--  * сотрудник видит только строки своего зала (staff.active = true);
--  * клиент (приложение) видит только свои строки (clients.user_id = auth.uid());
--  * деньги, абонементы, визиты и брони меняются только серверными функциями
--    (security definer, см. миграцию 3 и Edge Functions) — прямые INSERT/UPDATE закрыты;
--  * после окончания пробного периода без оплаты зал переходит в режим «только чтение».

-- ---------------------------------------------------------------------------
-- Вспомогательные функции
-- ---------------------------------------------------------------------------
create or replace function private.staff_role(p_gym uuid) returns public.staff_role
language sql stable security definer set search_path = public as $$
  select role from public.staff
   where gym_id = p_gym and user_id = auth.uid() and active
   limit 1
$$;

create or replace function private.is_staff(p_gym uuid, p_roles public.staff_role[] default null) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.staff
     where gym_id = p_gym and user_id = auth.uid() and active
       and (p_roles is null or role = any (p_roles))
  )
$$;

create or replace function private.my_staff_id(p_gym uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.staff where gym_id = p_gym and user_id = auth.uid() and active limit 1
$$;

create or replace function private.is_own_client(p_client uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.clients
                  where id = p_client and user_id = auth.uid() and deleted_at is null)
$$;

create or replace function private.is_client_of(p_gym uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.clients
                  where gym_id = p_gym and user_id = auth.uid() and deleted_at is null)
$$;

-- Сотрудник какого-либо зала (для него действует строгая изоляция: никаких строк чужих залов,
-- даже публичного каталога тарифов и расписания)
create or replace function private.is_any_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.staff where user_id = auth.uid() and active)
$$;

-- Публичный каталог зала (тарифы в продаже, зоны, расписание) видят сотрудники зала,
-- его клиенты и пользователи приложения, которые ещё выбирают зал
create or replace function private.can_see_catalog(p_gym uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select private.is_staff(p_gym) or private.is_client_of(p_gym) or not private.is_any_staff()
$$;

create or replace function private.is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid())
$$;

-- Зал может изменять данные, пока идёт пробный период или оплачена подписка (FR-10, приёмка)
create or replace function private.gym_writable(p_gym uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.gyms g
     where g.id = p_gym
       and (g.trial_until >= current_date or coalesce(g.paid_until, date '1900-01-01') >= current_date)
  )
$$;

create or replace function private.gym_today(p_gym uuid) returns date
language sql stable security definer set search_path = public as $$
  select (now() at time zone timezone)::date from public.gyms where id = p_gym
$$;

grant execute on all functions in schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Включаем RLS на всех таблицах
-- ---------------------------------------------------------------------------
alter table public.gyms                 enable row level security;
alter table public.staff                enable row level security;
alter table public.platform_admins      enable row level security;
alter table public.clients              enable row level security;
alter table public.membership_plans     enable row level security;
alter table public.memberships          enable row level security;
alter table public.freezes              enable row level security;
alter table public.payments             enable row level security;
alter table public.gym_secrets          enable row level security;
alter table public.visits               enable row level security;
alter table public.zones                enable row level security;
alter table public.schedule_items       enable row level security;
alter table public.bookings             enable row level security;
alter table public.client_devices       enable row level security;
alter table public.risk_contacts        enable row level security;
alter table public.notifications_outbox enable row level security;
alter table public.audit_log            enable row level security;

-- Анонимным пользователям таблицы недоступны вообще
revoke all on all tables in schema public from anon;

-- Денежные и учётные таблицы: только чтение через REST, изменения — через функции
revoke insert, update, delete on public.memberships, public.freezes, public.payments, public.visits,
  public.bookings, public.client_devices, public.audit_log, public.notifications_outbox,
  public.platform_admins, public.gym_secrets
  from authenticated;
revoke select on public.gym_secrets, public.notifications_outbox, public.platform_admins from authenticated;
-- Клиентов нельзя удалять физически — только обезличивать (FR-2.6)
revoke delete on public.clients from authenticated;

-- ---------------------------------------------------------------------------
-- gyms
-- ---------------------------------------------------------------------------
create policy gyms_select on public.gyms for select to authenticated
  using (private.is_staff(id) or private.is_platform_admin());
create policy gyms_update on public.gyms for update to authenticated
  using (private.is_staff(id, '{owner}') and private.gym_writable(id))
  with check (private.is_staff(id, '{owner}'));
-- Поля подписки меняет только команда core. (через admin_update_gym)
revoke update on public.gyms from authenticated;
grant update (name, address, timezone, phone, logo_url, settings, onboarded_at) on public.gyms to authenticated;
revoke insert, delete on public.gyms from authenticated;

-- Публичный каталог залов для приложения: без персональных данных и настроек
create view public.public_gyms as
  select id, name, address, timezone, phone, logo_url from public.gyms;
grant select on public.public_gyms to authenticated;

-- ---------------------------------------------------------------------------
-- staff: список видят сотрудники зала, управляет — владелец
-- ---------------------------------------------------------------------------
create policy staff_select on public.staff for select to authenticated
  using (private.is_staff(gym_id) or user_id = auth.uid());
create policy staff_insert on public.staff for insert to authenticated
  with check (private.is_staff(gym_id, '{owner}') and private.gym_writable(gym_id));
create policy staff_update on public.staff for update to authenticated
  using (private.is_staff(gym_id, '{owner}') and private.gym_writable(gym_id))
  with check (private.is_staff(gym_id, '{owner}'));
revoke delete on public.staff from authenticated;   -- «отключение сотрудника без удаления истории»

-- ---------------------------------------------------------------------------
-- clients
-- ---------------------------------------------------------------------------
create policy clients_select_staff on public.clients for select to authenticated
  using (private.is_staff(gym_id));
create policy clients_select_self on public.clients for select to authenticated
  using (user_id = auth.uid() and deleted_at is null);
create policy clients_insert on public.clients for insert to authenticated
  with check (private.is_staff(gym_id) and private.gym_writable(gym_id) and deleted_at is null);
create policy clients_update on public.clients for update to authenticated
  using (private.is_staff(gym_id) and private.gym_writable(gym_id) and deleted_at is null)
  with check (private.is_staff(gym_id));
-- Привязку к аккаунту и обезличивание делают только серверные функции
revoke update on public.clients from authenticated;
grant update (full_name, phone, email, birth_date, gender, source, tags, note, photo_url,
              consent_pd_at, consent_pd_text, consent_marketing_at, consent_marketing_text)
  on public.clients to authenticated;

-- ---------------------------------------------------------------------------
-- membership_plans: сотрудники видят свои, клиенты — продающиеся онлайн; меняет владелец
-- ---------------------------------------------------------------------------
create policy plans_select_staff on public.membership_plans for select to authenticated
  using (private.is_staff(gym_id));
create policy plans_select_online on public.membership_plans for select to authenticated
  using (sold_online and active and private.can_see_catalog(gym_id));
create policy plans_insert on public.membership_plans for insert to authenticated
  with check (private.is_staff(gym_id, '{owner}') and private.gym_writable(gym_id));
create policy plans_update on public.membership_plans for update to authenticated
  using (private.is_staff(gym_id, '{owner}') and private.gym_writable(gym_id))
  with check (private.is_staff(gym_id, '{owner}'));
revoke delete on public.membership_plans from authenticated;   -- тариф отключается флагом active

-- ---------------------------------------------------------------------------
-- memberships, freezes
-- ---------------------------------------------------------------------------
create policy memberships_select on public.memberships for select to authenticated
  using (private.is_staff(gym_id) or private.is_own_client(client_id));
create policy freezes_select on public.freezes for select to authenticated
  using (private.is_staff(gym_id)
         or exists (select 1 from public.memberships m where m.id = membership_id and private.is_own_client(m.client_id)));

-- ---------------------------------------------------------------------------
-- payments: выручку видят владелец и администратор; клиент — свои оплаты
-- ---------------------------------------------------------------------------
create policy payments_select on public.payments for select to authenticated
  using (private.is_staff(gym_id, '{owner,admin}') or private.is_own_client(client_id));

-- ---------------------------------------------------------------------------
-- visits
-- ---------------------------------------------------------------------------
create policy visits_select on public.visits for select to authenticated
  using (private.is_staff(gym_id) or private.is_own_client(client_id));

-- ---------------------------------------------------------------------------
-- zones, schedule_items: публичный каталог (см. can_see_catalog), настраивают владелец и администратор
-- ---------------------------------------------------------------------------
create policy zones_select on public.zones for select to authenticated using (private.can_see_catalog(gym_id));
create policy zones_write on public.zones for insert to authenticated
  with check (private.is_staff(gym_id, '{owner,admin}') and private.gym_writable(gym_id));
create policy zones_update on public.zones for update to authenticated
  using (private.is_staff(gym_id, '{owner,admin}') and private.gym_writable(gym_id))
  with check (private.is_staff(gym_id, '{owner,admin}'));
create policy zones_delete on public.zones for delete to authenticated
  using (private.is_staff(gym_id, '{owner,admin}') and private.gym_writable(gym_id));

create policy schedule_select on public.schedule_items for select to authenticated using (private.can_see_catalog(gym_id));
create policy schedule_insert on public.schedule_items for insert to authenticated
  with check (private.is_staff(gym_id, '{owner,admin}') and private.gym_writable(gym_id));
create policy schedule_update on public.schedule_items for update to authenticated
  using (private.is_staff(gym_id, '{owner,admin}') and private.gym_writable(gym_id))
  with check (private.is_staff(gym_id, '{owner,admin}'));
-- Отмена занятия — через cancel_class (уведомляет записавшихся)
revoke delete on public.schedule_items from authenticated;

-- ---------------------------------------------------------------------------
-- bookings
-- ---------------------------------------------------------------------------
create policy bookings_select on public.bookings for select to authenticated
  using (private.is_staff(gym_id) or private.is_own_client(client_id));

-- ---------------------------------------------------------------------------
-- client_devices: клиент видит свои устройства
-- ---------------------------------------------------------------------------
create policy devices_select on public.client_devices for select to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- risk_contacts: все роли зала (ресепшен тоже работает со списком)
-- ---------------------------------------------------------------------------
create policy risk_contacts_select on public.risk_contacts for select to authenticated
  using (private.is_staff(gym_id));
revoke insert, update, delete on public.risk_contacts from authenticated;   -- через mark_contacted

-- ---------------------------------------------------------------------------
-- audit_log: только владелец
-- ---------------------------------------------------------------------------
create policy audit_select on public.audit_log for select to authenticated
  using (private.is_staff(gym_id, '{owner}'));

-- ---------------------------------------------------------------------------
-- Журнал изменений денег и абонементов (FR-1.4)
-- ---------------------------------------------------------------------------
create or replace function private.audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_diff jsonb;
  v_gym uuid := coalesce((v_new ->> 'gym_id')::uuid, (v_old ->> 'gym_id')::uuid);
  v_id uuid := coalesce((v_new ->> 'id')::uuid, (v_old ->> 'id')::uuid);
begin
  if tg_table_name = 'gyms' then v_gym := v_id; end if;
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(k, jsonb_build_array(v_old -> k, v_new -> k))
      into v_diff
      from jsonb_object_keys(v_new) k
     where k <> 'updated_at' and (v_old -> k) is distinct from (v_new -> k);
    if v_diff is null then return new; end if;
  elsif tg_op = 'INSERT' then
    v_diff := v_new - 'updated_at' - 'created_at';
  else
    v_diff := v_old;
  end if;
  -- секрет QR и токены в журнал не пишем
  v_diff := v_diff - 'qr_secret' - 'push_token';
  insert into public.audit_log (gym_id, actor_user_id, action, entity, entity_id, diff)
  values (v_gym, auth.uid(), lower(tg_op), tg_table_name, v_id, v_diff);
  return coalesce(new, old);
end $$;

create trigger memberships_audit after insert or update or delete on public.memberships
  for each row execute function private.audit_trigger();
create trigger payments_audit after insert or update or delete on public.payments
  for each row execute function private.audit_trigger();
create trigger freezes_audit after insert or update or delete on public.freezes
  for each row execute function private.audit_trigger();
create trigger plans_audit after insert or update or delete on public.membership_plans
  for each row execute function private.audit_trigger();
create trigger staff_audit after insert or update or delete on public.staff
  for each row execute function private.audit_trigger();
create trigger gyms_audit after update on public.gyms
  for each row execute function private.audit_trigger();
