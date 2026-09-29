-- core. — полная установка базы для Supabase Cloud: вставьте весь файл в SQL Editor и нажмите Run.
-- Собрано из supabase/migrations/*.sql и supabase/seed.sql (демо-зал «Атлет», пароль demo12345).

-- ===== supabase/migrations/20260928000001_schema.sql
-- core. MVP — схема базы данных (раздел 4 ТЗ)
-- Все суммы — в копейках (bigint), все даты-время — timestamptz (UTC), показ — в часовом поясе зала.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists btree_gist with schema extensions;
create extension if not exists pg_trgm with schema extensions;

-- Служебная схема для внутренних функций (не публикуется через REST)
create schema if not exists private;
grant usage on schema private to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- Типы
-- ---------------------------------------------------------------------------
create type public.staff_role        as enum ('owner', 'admin', 'reception');
create type public.core_plan         as enum ('start', 'business', 'network');
create type public.plan_kind         as enum ('period', 'visits', 'unlimited');
-- pending — абонемент создан под онлайн-оплату и ждёт подтверждения ЮKassa
create type public.membership_status as enum ('pending', 'active', 'frozen', 'expired', 'cancelled');
create type public.payment_method    as enum ('cash', 'card', 'online');
create type public.payment_status    as enum ('pending', 'succeeded', 'refunded', 'failed');
create type public.visit_method      as enum ('qr', 'manual');
create type public.schedule_kind     as enum ('class', 'personal', 'zone_slot');
create type public.booking_status    as enum ('booked', 'cancelled', 'attended', 'no_show');
create type public.booking_channel   as enum ('app', 'staff');

-- ---------------------------------------------------------------------------
-- Общие триггеры
-- ---------------------------------------------------------------------------
create or replace function private.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Приведение телефона к формату +7XXXXXXXXXX (раздел 8: «телефоны приводятся к формату +7»)
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
  elsif left(p, 1) = '+' and length(d) between 10 and 15 then
    return '+' || d;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Залы
-- ---------------------------------------------------------------------------
create table public.gyms (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (length(trim(name)) > 0),
  address       text,
  timezone      text not null default 'Europe/Moscow',
  phone         text,
  logo_url      text,
  core_plan     public.core_plan not null default 'start',
  trial_until   date not null default (current_date + 14),
  paid_until    date,                           -- подписка на core. ведётся вручную (FR-10)
  features      jsonb not null default '{}',    -- флаги функций поверх тарифа (FR-10.2)
  settings      jsonb not null default '{
    "risk": {"gone_days": 10, "expiring_days": 7, "declining_ratio": 0.5, "not_renewed_days": 14},
    "hours": {"mon": ["07:00","23:00"], "tue": ["07:00","23:00"], "wed": ["07:00","23:00"],
              "thu": ["07:00","23:00"], "fri": ["07:00","23:00"], "sat": ["09:00","21:00"], "sun": ["09:00","21:00"]},
    "auto_checkout_hours": 3,
    "booking_cancel_hours": 2,
    "allow_app_freeze": true,
    "capacity": 50,
    "notify_fallback": "sms",
    "message_templates": {
      "gone": "{name}, давно вас не видели в {gym}! Ждём на тренировке — если что-то мешает, напишите нам.",
      "expiring": "{name}, ваш абонемент в {gym} заканчивается {date}. Продлите заранее, чтобы не прерывать тренировки.",
      "declining": "{name}, заметили, что вы стали реже приходить в {gym}. Можем подобрать удобное время или тренера?",
      "not_renewed": "{name}, ваш абонемент в {gym} закончился. Возвращайтесь — поможем с продлением."
    }
  }',
  onboarded_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.staff (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid not null references public.gyms(id) on delete cascade,
  user_id     uuid references auth.users(id) on delete set null,
  email       text not null,
  role        public.staff_role not null,
  full_name   text not null,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (gym_id, user_id),
  unique (gym_id, email)
);
create index staff_user_idx on public.staff(user_id) where active;

-- Команда core. (служебная роль «Суперадмин»)
create table public.platform_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Клиенты
-- ---------------------------------------------------------------------------
create table public.clients (
  id                   uuid primary key default gen_random_uuid(),
  gym_id               uuid not null references public.gyms(id) on delete cascade,
  user_id              uuid references auth.users(id) on delete set null,  -- null, пока не вошёл в приложение
  full_name            text not null check (length(trim(full_name)) > 0),
  phone                text,                                               -- null только у обезличенных
  email                text,
  birth_date           date,
  gender               text check (gender in ('male', 'female')),
  source               text,
  tags                 text[] not null default '{}',
  note                 text,
  photo_url            text,
  consent_pd_at        timestamptz,
  consent_pd_text      text,
  consent_marketing_at timestamptz,
  consent_marketing_text text,
  last_visit_at        timestamptz,     -- денормализация для списка и «зоны риска»
  deleted_at           timestamptz,     -- мягкое удаление / обезличивание (FR-2.6)
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  check (deleted_at is not null or phone is not null)
);
create unique index clients_gym_phone_uq on public.clients(gym_id, phone) where deleted_at is null;
create index clients_gym_idx on public.clients(gym_id) where deleted_at is null;
create index clients_user_idx on public.clients(user_id);
create index clients_name_trgm_idx on public.clients using gin (lower(full_name) extensions.gin_trgm_ops);

create or replace function private.clients_normalize() returns trigger
language plpgsql as $$
begin
  if new.phone is not null then
    new.phone := public.normalize_phone(new.phone);
    if new.phone is null then
      raise exception 'Некорректный номер телефона' using hint = 'INVALID_PHONE';
    end if;
  end if;
  new.full_name := regexp_replace(trim(new.full_name), '\s+', ' ', 'g');
  if new.email is not null then new.email := nullif(lower(trim(new.email)), ''); end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Тарифы и абонементы
-- ---------------------------------------------------------------------------
create table public.membership_plans (
  id              uuid primary key default gen_random_uuid(),
  gym_id          uuid not null references public.gyms(id) on delete cascade,
  name            text not null,
  description     text,
  kind            public.plan_kind not null,
  price           bigint not null check (price >= 0),          -- копейки
  duration_days   int not null check (duration_days > 0),
  visits_limit    int check (visits_limit is null or visits_limit > 0),
  freeze_days_max int not null default 0 check (freeze_days_max >= 0),
  sold_online     boolean not null default false,
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check ((kind = 'visits') = (visits_limit is not null))
);
create index membership_plans_gym_idx on public.membership_plans(gym_id);

create table public.memberships (
  id               uuid primary key default gen_random_uuid(),
  gym_id           uuid not null references public.gyms(id) on delete cascade,
  client_id        uuid not null references public.clients(id) on delete cascade,
  plan_id          uuid references public.membership_plans(id) on delete set null,
  plan_name        text not null,                 -- снимок названия тарифа
  kind             public.plan_kind not null,     -- снимок типа тарифа
  starts_on        date not null,
  ends_on          date not null,
  visits_left      int check (visits_left is null or visits_left >= 0),
  freeze_days_max  int not null default 0,        -- снимок лимита заморозки
  freeze_days_used int not null default 0,
  status           public.membership_status not null default 'active',
  price_paid       bigint not null default 0 check (price_paid >= 0),  -- цена фиксируется на момент продажи
  renewed_from_id  uuid references public.memberships(id) on delete set null,
  imported         boolean not null default false,
  cancelled_at     timestamptz,
  created_by       uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (ends_on >= starts_on),
  check (freeze_days_used <= freeze_days_max),
  -- У клиента не может быть двух пересекающихся действующих абонементов (приёмка FR-3)
  constraint memberships_no_overlap exclude using gist (
    client_id with =,
    daterange(starts_on, ends_on, '[]') with &&
  ) where (status in ('active', 'frozen')) deferrable initially immediate
);
create index memberships_client_idx on public.memberships(client_id, ends_on desc);
create index memberships_gym_ends_idx on public.memberships(gym_id, ends_on);
create index memberships_gym_created_idx on public.memberships(gym_id, created_at);

create table public.freezes (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references public.gyms(id) on delete cascade,
  membership_id uuid not null references public.memberships(id) on delete cascade,
  from_date     date not null,
  to_date       date not null,
  days          int generated always as (to_date - from_date + 1) stored,
  reason        text,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (to_date >= from_date),
  constraint freezes_no_overlap exclude using gist (
    membership_id with =,
    daterange(from_date, to_date, '[]') with &&
  )
);
create index freezes_membership_idx on public.freezes(membership_id);

-- ---------------------------------------------------------------------------
-- Оплаты
-- ---------------------------------------------------------------------------
create table public.payments (
  id                  uuid primary key default gen_random_uuid(),
  gym_id              uuid not null references public.gyms(id) on delete cascade,
  client_id           uuid references public.clients(id) on delete set null,
  membership_id       uuid references public.memberships(id) on delete set null,
  amount              bigint not null check (amount > 0),   -- копейки; у возврата — сумма возврата
  method              public.payment_method not null,
  status              public.payment_status not null default 'pending',
  provider            text,                                  -- yookassa / cloudpayments
  provider_payment_id text,
  confirmation_url    text,
  receipt_url         text,
  description         text,
  staff_id            uuid references public.staff(id) on delete set null,
  refund_of_id        uuid references public.payments(id) on delete restrict,  -- строка-возврат ссылается на исходную оплату
  paid_at             timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create unique index payments_provider_uq on public.payments(provider, provider_payment_id) where provider_payment_id is not null;
create index payments_gym_paid_idx on public.payments(gym_id, paid_at);
create index payments_client_idx on public.payments(client_id);
create index payments_refund_of_idx on public.payments(refund_of_id) where refund_of_id is not null;

-- Ключи ЮKassa зала — в зашифрованном виде, доступ только у сервера (service_role)
create table public.gym_secrets (
  gym_id                    uuid primary key references public.gyms(id) on delete cascade,
  yookassa_shop_id          text,
  yookassa_secret_encrypted text,    -- AES-256-GCM, ключ шифрования — переменная окружения сервера
  yookassa_send_receipt     boolean not null default true,   -- чеки по 54-ФЗ через ЮKassa
  vat_code                  int not null default 1,          -- код НДС для чека (1 — без НДС)
  updated_at                timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Посещения
-- ---------------------------------------------------------------------------
create table public.visits (
  id             uuid primary key default gen_random_uuid(),
  gym_id         uuid not null references public.gyms(id) on delete cascade,
  client_id      uuid not null references public.clients(id) on delete cascade,
  membership_id  uuid references public.memberships(id) on delete set null,
  checked_in_at  timestamptz not null default now(),
  checked_out_at timestamptz,
  method         public.visit_method not null,
  staff_id       uuid references public.staff(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index visits_gym_time_idx on public.visits(gym_id, checked_in_at);
create index visits_client_time_idx on public.visits(client_id, checked_in_at desc);
create index visits_open_idx on public.visits(gym_id) where checked_out_at is null;

-- ---------------------------------------------------------------------------
-- Расписание и бронь
-- ---------------------------------------------------------------------------
create table public.zones (
  id         uuid primary key default gen_random_uuid(),
  gym_id     uuid not null references public.gyms(id) on delete cascade,
  name       text not null,
  capacity   int not null default 10 check (capacity > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index zones_gym_idx on public.zones(gym_id);

create table public.schedule_items (
  id               uuid primary key default gen_random_uuid(),
  gym_id           uuid not null references public.gyms(id) on delete cascade,
  kind             public.schedule_kind not null default 'class',
  title            text not null,
  description      text,
  zone_id          uuid references public.zones(id) on delete set null,
  trainer_name     text,
  starts_at        timestamptz not null,
  ends_at          timestamptz not null,
  capacity         int not null default 10 check (capacity > 0),
  recurrence_rule  text,        -- RRULE-подобное правило серии, напр. FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231
  series_id        uuid,        -- все занятия одной серии
  cancelled        boolean not null default false,
  cancelled_reason text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index schedule_items_gym_time_idx on public.schedule_items(gym_id, starts_at);
create index schedule_items_series_idx on public.schedule_items(series_id) where series_id is not null;

create table public.bookings (
  id               uuid primary key default gen_random_uuid(),
  gym_id           uuid not null references public.gyms(id) on delete cascade,
  schedule_item_id uuid not null references public.schedule_items(id) on delete cascade,
  client_id        uuid not null references public.clients(id) on delete cascade,
  status           public.booking_status not null default 'booked',
  channel          public.booking_channel not null,
  cancelled_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (schedule_item_id, client_id)          -- уникально: клиент + занятие
);
create index bookings_client_idx on public.bookings(client_id);
create index bookings_item_idx on public.bookings(schedule_item_id) where status in ('booked', 'attended');

-- ---------------------------------------------------------------------------
-- Устройства клиентов (push и секрет динамического QR)
-- ---------------------------------------------------------------------------
create table public.client_devices (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid references public.clients(id) on delete set null,   -- клиент, от имени которого устройство зарегистрировано впервые
  user_id     uuid not null references auth.users(id) on delete cascade,
  platform    text not null check (platform in ('ios', 'android', 'web', 'telegram')),
  push_token  text,
  qr_secret   text not null default encode(extensions.gen_random_bytes(32), 'hex'),
  revoked_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index client_devices_user_idx on public.client_devices(user_id) where revoked_at is null;

-- ---------------------------------------------------------------------------
-- «В зоне риска»: отметки контакта (FR-8.2) и счётчик «вернулись» (FR-8.3)
-- ---------------------------------------------------------------------------
create table public.risk_contacts (
  id           uuid primary key default gen_random_uuid(),
  gym_id       uuid not null references public.gyms(id) on delete cascade,
  client_id    uuid not null references public.clients(id) on delete cascade,
  reason       text not null,
  channel      text not null check (channel in ('call', 'telegram', 'whatsapp', 'push', 'other')),
  note         text,
  staff_id     uuid references public.staff(id) on delete set null,
  contacted_at timestamptz not null default now(),
  returned_at  timestamptz,     -- заполняется при визите или покупке после контакта
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index risk_contacts_client_idx on public.risk_contacts(client_id, contacted_at desc);
create index risk_contacts_gym_idx on public.risk_contacts(gym_id, contacted_at);

-- ---------------------------------------------------------------------------
-- Очередь уведомлений (раздел 5.9); отправку делает Edge Function notify
-- ---------------------------------------------------------------------------
create table public.notifications_outbox (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references public.gyms(id) on delete cascade,
  client_id     uuid not null references public.clients(id) on delete cascade,
  kind          text not null,   -- booking_confirmed, booking_cancelled, class_cancelled, class_reminder, membership_expiring, risk_push
  service       boolean not null, -- сервисные уходят без согласия на рассылки
  title         text not null,
  body          text not null,
  data          jsonb not null default '{}',
  dedupe_key    text,
  send_after    timestamptz not null default now(),
  status        text not null default 'queued' check (status in ('queued', 'sent', 'skipped', 'failed')),
  channel       text,           -- push / sms / email — фактический канал
  attempts      int not null default 0,
  last_error    text,
  sent_at       timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index notifications_dedupe_uq on public.notifications_outbox(dedupe_key) where dedupe_key is not null;
create index notifications_queue_idx on public.notifications_outbox(send_after) where status = 'queued';

-- ---------------------------------------------------------------------------
-- Журнал действий
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id            bigint generated always as identity primary key,
  gym_id        uuid references public.gyms(id) on delete cascade,
  actor_user_id uuid,
  action        text not null,    -- insert / update / delete
  entity        text not null,
  entity_id     uuid,
  diff          jsonb,
  at            timestamptz not null default now()
);
create index audit_log_gym_at_idx on public.audit_log(gym_id, at desc);

-- ---------------------------------------------------------------------------
-- Триггеры updated_at и нормализации
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['gyms','staff','clients','membership_plans','memberships','freezes','payments',
                           'visits','zones','schedule_items','bookings','client_devices','risk_contacts',
                           'notifications_outbox']
  loop
    execute format('create trigger %I before update on public.%I for each row execute function private.touch_updated_at()',
                   t || '_touch', t);
  end loop;
end $$;

create trigger clients_normalize before insert or update of phone, full_name, email on public.clients
  for each row execute function private.clients_normalize();

-- ===== supabase/migrations/20260928000002_rls.sql
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

-- ===== supabase/migrations/20260928000003_business.sql
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

-- ===== supabase/migrations/20260928000004_analytics.sql
-- core. MVP — аналитика: дашборд (5.7), «в зоне риска» (5.8), загруженность, списки.
-- Представления создаются с security_invoker, поэтому к ним применяются политики RLS вызывающего.

-- ---------------------------------------------------------------------------
-- «В зоне риска» (5.8). Список живой: пересчитывается при каждом запросе,
-- то есть сразу после визита или продажи, и ночью ничего пересчитывать не нужно.
-- ---------------------------------------------------------------------------
create or replace view public.v_client_risk with (security_invoker = true) as
with base as (
  select c.id as client_id, c.gym_id, c.full_name, c.phone, c.user_id is not null as in_app,
         c.consent_marketing_at is not null as marketing_ok, c.last_visit_at, c.tags,
         (now() at time zone g.timezone)::date as today,
         (c.last_visit_at at time zone g.timezone)::date as last_visit_on,
         coalesce((g.settings -> 'risk' ->> 'gone_days')::int, 10) as gone_days,
         coalesce((g.settings -> 'risk' ->> 'expiring_days')::int, 7) as expiring_days,
         coalesce((g.settings -> 'risk' ->> 'declining_ratio')::numeric, 0.5) as declining_ratio,
         coalesce((g.settings -> 'risk' ->> 'not_renewed_days')::int, 14) as not_renewed_days
    from public.clients c
    join public.gyms g on g.id = c.gym_id
   where c.deleted_at is null
),
facts as (
  select b.*,
         cur.id as membership_id, cur.starts_on as cur_starts_on, cur.ends_on as cur_ends_on,
         coalesce(cur.frozen, false) as frozen,
         exists (select 1 from public.memberships n
                  where n.client_id = b.client_id and n.status in ('active', 'frozen')
                    and n.starts_on > greatest(b.today, coalesce(cur.ends_on, b.today))) as has_next,
         (select max(m.ends_on) from public.memberships m
           where m.client_id = b.client_id and m.status in ('active', 'frozen', 'expired')) as last_ends_on,
         coalesce(vs.recent, 0) as visits_recent,
         coalesce(vs.prev, 0) as visits_prev
    from base b
    left join lateral (
      select m.id, m.starts_on, m.ends_on,
             exists (select 1 from public.freezes f
                      where f.membership_id = m.id and b.today between f.from_date and f.to_date) as frozen
        from public.memberships m
       where m.client_id = b.client_id and m.status in ('active', 'frozen')
         and b.today between m.starts_on and m.ends_on
       order by m.ends_on desc limit 1
    ) cur on true
    left join lateral (
      select count(*) filter (where v.checked_in_at >= now() - interval '14 days') as recent,
             count(*) filter (where v.checked_in_at < now() - interval '14 days') as prev
        from public.visits v
       where v.client_id = b.client_id and v.checked_in_at >= now() - interval '56 days'
    ) vs on true
),
flags as (
  select f.*,
         f.today - greatest(f.last_visit_on, f.cur_starts_on) as days_absent,
         f.cur_ends_on - f.today as days_left,
         f.today - f.last_ends_on as days_since_end,
         -- Пропал: активный абонемент и нет визитов N+ дней
         (f.membership_id is not null and not f.frozen
          and f.today - greatest(f.last_visit_on, f.cur_starts_on) >= f.gone_days) as is_gone,
         -- Заканчивается: истекает через N дней или меньше, продления нет
         (f.membership_id is not null and not f.has_next
          and f.cur_ends_on - f.today between 0 and f.expiring_days) as is_expiring,
         -- Стал ходить реже: за 2 недели вдвое меньше, чем в среднем за 2 недели в 6 недель до этого
         (f.membership_id is not null and not f.frozen and f.visits_prev >= 3
          and f.visits_recent < f.declining_ratio * (f.visits_prev / 3.0)) as is_declining,
         -- Не продлил: абонемент закончился менее N дней назад (на N-й день это уже отток)
         (f.membership_id is null and not f.has_next and f.last_ends_on is not null
          and f.today - f.last_ends_on between 1 and f.not_renewed_days - 1) as is_not_renewed
    from facts f
)
select fl.gym_id, fl.client_id, fl.full_name, fl.phone, fl.in_app, fl.marketing_ok, fl.tags,
       fl.last_visit_at, fl.membership_id, fl.cur_ends_on as membership_ends_on,
       fl.days_absent, fl.days_left, fl.days_since_end, fl.visits_recent, fl.visits_prev,
       case when fl.is_not_renewed then 'not_renewed'
            when fl.is_expiring then 'expiring'
            when fl.is_gone then 'gone'
            else 'declining' end as reason,
       array_remove(array[
         case when fl.is_not_renewed then 'not_renewed' end,
         case when fl.is_expiring then 'expiring' end,
         case when fl.is_gone then 'gone' end,
         case when fl.is_declining then 'declining' end], null) as reasons,
       case when fl.is_not_renewed then 'Не продлил: абонемент закончился ' || fl.days_since_end || ' дн. назад'
            when fl.is_expiring then case when fl.days_left = 0 then 'Абонемент заканчивается сегодня'
                                          else 'Абонемент заканчивается через ' || fl.days_left || ' дн.' end
            when fl.is_gone then 'Пропал: не приходит ' || fl.days_absent || ' дн.'
            else 'Стал ходить реже: ' || fl.visits_recent || ' виз. за 2 нед. вместо ~' ||
                 round(fl.visits_prev / 3.0, 1) end as reason_text,
       -- срочность: сначала те, кого вот-вот потеряем
       case when fl.is_not_renewed then 3000 + fl.days_since_end * 10
            when fl.is_expiring then 2000 + (fl.expiring_days - fl.days_left) * 10
            when fl.is_gone then 1000 + fl.days_absent
            else 500 + (fl.visits_prev / 3.0 - fl.visits_recent)::int end as urgency,
       rc.contacted_at, rc.channel as contact_channel
  from flags fl
  left join lateral (
    select r.contacted_at, r.channel from public.risk_contacts r
     where r.client_id = fl.client_id and r.contacted_at >= now() - interval '14 days'
     order by r.contacted_at desc limit 1
  ) rc on true
 where fl.is_gone or fl.is_expiring or fl.is_declining or fl.is_not_renewed;

-- ---------------------------------------------------------------------------
-- Список клиентов с состоянием абонемента (FR-2.1)
-- ---------------------------------------------------------------------------
create or replace view public.v_clients with (security_invoker = true) as
select c.id, c.gym_id, c.full_name, c.phone, c.email, c.source, c.tags, c.user_id is not null as in_app,
       c.last_visit_at, c.created_at, c.photo_url,
       ms.id as membership_id, ms.plan_name, ms.ends_on as membership_ends_on, ms.visits_left,
       case
         when ms.id is null and fut.id is not null then 'future'
         when ms.id is null and c.has_any then 'expired'
         when ms.id is null then 'none'
         when ms.frozen then 'frozen'
         else 'active'
       end as membership_state
  from (select c0.*, exists (select 1 from public.memberships m0 where m0.client_id = c0.id
                               and m0.status in ('active', 'frozen', 'expired')) as has_any,
               (now() at time zone g.timezone)::date as today
          from public.clients c0 join public.gyms g on g.id = c0.gym_id
         where c0.deleted_at is null) c
  left join lateral (
    select m.id, m.plan_name, m.ends_on, m.visits_left,
           exists (select 1 from public.freezes f where f.membership_id = m.id
                     and c.today between f.from_date and f.to_date) as frozen
      from public.memberships m
     where m.client_id = c.id and m.status in ('active', 'frozen') and c.today between m.starts_on and m.ends_on
     order by m.ends_on desc limit 1
  ) ms on true
  left join lateral (
    select m.id from public.memberships m
     where m.client_id = c.id and m.status in ('active', 'frozen') and m.starts_on > c.today limit 1
  ) fut on true;

-- ---------------------------------------------------------------------------
-- «Кто сейчас в зале» (FR-4.5): открытые визиты с учётом автоматического выхода
-- ---------------------------------------------------------------------------
create or replace view public.v_in_gym with (security_invoker = true) as
select v.id as visit_id, v.gym_id, v.client_id, c.full_name, c.photo_url, v.checked_in_at, v.method,
       m.plan_name, m.ends_on as membership_ends_on, m.visits_left
  from public.visits v
  join public.clients c on c.id = v.client_id
  join public.gyms g on g.id = v.gym_id
  left join public.memberships m on m.id = v.membership_id
 where v.checked_out_at is null
   and v.checked_in_at > now() - make_interval(hours => coalesce((g.settings ->> 'auto_checkout_hours')::int, 3));

-- ---------------------------------------------------------------------------
-- Загруженность: сейчас и тепловая карта «день недели × час» за 4 недели. Без персональных данных.
-- ---------------------------------------------------------------------------
create or replace function public.gym_occupancy(p_gym uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  g public.gyms;
  v_hours int;
  v_now int;
  v_capacity int;
  v_heat jsonb;
  v_today_forecast jsonb;
begin
  select * into g from public.gyms where id = p_gym;
  if g.id is null then perform private.fail('GYM_NOT_FOUND', 'Зал не найден'); end if;
  v_hours := coalesce((g.settings ->> 'auto_checkout_hours')::int, 3);
  v_capacity := coalesce(nullif((g.settings ->> 'capacity')::int, 0),
                         (select sum(capacity)::int from public.zones where gym_id = p_gym), 0);

  select count(*) into v_now from public.visits
   where gym_id = p_gym and checked_out_at is null and checked_in_at > now() - make_interval(hours => v_hours);

  -- каждый визит раскладываем по часам, которые он покрывает, и считаем людей в каждом часе
  with v as (
    select checked_in_at s,
           coalesce(checked_out_at, least(checked_in_at + make_interval(hours => v_hours), now())) e
      from public.visits
     where gym_id = p_gym and checked_in_at >= now() - interval '28 days' - make_interval(hours => v_hours)
  ), buckets as (
    select h, count(*) as people
      from v cross join lateral generate_series(date_trunc('hour', v.s), v.e - interval '1 microsecond', interval '1 hour') h
     where h >= date_trunc('hour', now() - interval '28 days') and h < date_trunc('hour', now())
     group by h
  ), per_hour as (
    select hs.h, coalesce(b.people, 0) as people
      from generate_series(date_trunc('hour', now() - interval '28 days'),
                           date_trunc('hour', now()) - interval '1 hour', interval '1 hour') hs(h)
      left join buckets b on b.h = hs.h
  ), agg as (
    select extract(isodow from h at time zone g.timezone)::int as dow,
           extract(hour from h at time zone g.timezone)::int as hour,
           round(avg(people)::numeric, 1) as avg_people
      from per_hour group by 1, 2
  )
  select coalesce(jsonb_agg(jsonb_build_object('dow', dow, 'hour', hour, 'avg', avg_people) order by dow, hour), '[]')
    into v_heat from agg;

  select coalesce(jsonb_agg(jsonb_build_object('hour', (x ->> 'hour')::int, 'avg', (x ->> 'avg')::numeric)
                            order by (x ->> 'hour')::int), '[]')
    into v_today_forecast
    from jsonb_array_elements(v_heat) x
   where (x ->> 'dow')::int = extract(isodow from now() at time zone g.timezone)::int;

  return jsonb_build_object('now', v_now, 'capacity', v_capacity,
                            'load_pct', case when v_capacity > 0 then round(100.0 * v_now / v_capacity) end,
                            'heatmap', v_heat, 'today_forecast', v_today_forecast,
                            'timezone', g.timezone, 'generated_at', now());
end $$;

-- ---------------------------------------------------------------------------
-- Дашборд (5.7). Формулы зафиксированы в ТЗ — считаем ровно так.
-- ---------------------------------------------------------------------------
-- Абонемент m «продлён», если за ним куплен другой абонемент, заканчивающийся позже,
-- не позднее 14 дней после окончания m.
create or replace function private.is_renewed(m public.memberships, p_tz text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.memberships n
     where n.client_id = m.client_id and n.id <> m.id
       and n.status not in ('cancelled', 'pending')
       and n.ends_on > m.ends_on
       and case when n.imported then n.starts_on <= m.ends_on + 15
                else (n.created_at at time zone p_tz)::date <= m.ends_on + 14 end
  )
$$;

create or replace function private.kpi_period(p_gym uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text;
  v_today date;
  v_end date;
  v_ts_from timestamptz;
  v_ts_to timestamptz;
  v_revenue bigint;
  v_active int;
  v_ended int;
  v_renewed int;
  v_churn int;
  v_new int;
  v_by_source jsonb;
begin
  select timezone into v_tz from public.gyms where id = p_gym;
  v_today := (now() at time zone v_tz)::date;
  v_end := least(p_to, v_today);
  v_ts_from := p_from::timestamp at time zone v_tz;
  v_ts_to := (p_to + 1)::timestamp at time zone v_tz;

  -- Выручка: успешные оплаты минус возвраты
  select coalesce(sum(case when refund_of_id is null then amount else -amount end), 0) into v_revenue
    from public.payments
   where gym_id = p_gym and paid_at >= v_ts_from and paid_at < v_ts_to
     and ((refund_of_id is null and status in ('succeeded', 'refunded'))
          or (refund_of_id is not null and status = 'refunded'));

  -- Активные клиенты: абонемент active или frozen на конец периода
  select count(distinct client_id) into v_active
    from public.memberships
   where gym_id = p_gym and status not in ('cancelled', 'pending')
     and starts_on <= v_end and ends_on >= v_end;

  -- Процент продления: из закончившихся в периоде — доля продлённых в течение 14 дней
  select count(*), count(*) filter (where private.is_renewed(m, v_tz))
    into v_ended, v_renewed
    from public.memberships m
   where m.gym_id = p_gym and m.status not in ('cancelled', 'pending')
     and m.ends_on between p_from and least(p_to, v_today - 1);

  -- Отток: клиенты, чей абонемент закончился и не продлён 14 дней (событие — 14-й день)
  select count(distinct m.client_id) into v_churn
    from public.memberships m
   where m.gym_id = p_gym and m.status not in ('cancelled', 'pending')
     and m.ends_on + 14 between p_from and least(p_to, v_today)
     and not private.is_renewed(m, v_tz);

  -- Новые клиенты: первый абонемент куплен в периоде; разбивка по источнику
  with firsts as (
    select m.client_id,
           min(case when m.imported then m.starts_on else (m.created_at at time zone v_tz)::date end) as first_on
      from public.memberships m
     where m.gym_id = p_gym and m.status not in ('cancelled', 'pending')
     group by m.client_id
  ), fresh as (
    select coalesce(nullif(c.source, ''), 'не указан') as source
      from firsts f join public.clients c on c.id = f.client_id
     where f.first_on between p_from and p_to
  )
  select count(*),
         coalesce((select jsonb_agg(jsonb_build_object('source', source, 'count', n) order by n desc)
                     from (select source, count(*) n from fresh group by source) s), '[]')
    into v_new, v_by_source
    from fresh;

  return jsonb_build_object(
    'revenue', v_revenue,
    'active_clients', v_active,
    'renewal_rate', case when v_ended > 0 then round(100.0 * v_renewed / v_ended, 1) end,
    'renewal_ended', v_ended,
    'renewal_renewed', v_renewed,
    'churn', v_churn,
    'new_clients', v_new,
    'new_by_source', v_by_source);
end $$;

create or replace function public.dashboard_kpi(p_gym uuid, p_from date default null, p_to date default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_today date;
  v_from date;
  v_to date;
  v_len int;
  v_prev_from date;
  v_prev_to date;
begin
  perform private.require_staff(p_gym, '{owner,admin}', false);
  v_today := private.gym_today(p_gym);
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);
  if v_to < v_from then perform private.fail('INVALID_DATE', 'Конец периода раньше начала'); end if;
  -- предыдущий период той же длины; для календарного месяца — предыдущий месяц целиком
  if v_from = date_trunc('month', v_from)::date and v_to = (date_trunc('month', v_from) + interval '1 month - 1 day')::date then
    v_prev_from := (v_from - interval '1 month')::date;
    v_prev_to := v_from - 1;
  else
    v_len := v_to - v_from + 1;
    v_prev_to := v_from - 1;
    v_prev_from := v_from - v_len;
  end if;
  return jsonb_build_object(
    'period', jsonb_build_object('from', v_from, 'to', v_to),
    'previous_period', jsonb_build_object('from', v_prev_from, 'to', v_prev_to),
    'current', private.kpi_period(p_gym, v_from, v_to),
    'previous', private.kpi_period(p_gym, v_prev_from, v_prev_to),
    'occupancy', public.gym_occupancy(p_gym));
end $$;

-- 6 метрик по месяцам за последние 24 месяца (для отчётов)
create or replace view public.v_gym_kpi_month with (security_invoker = true) as
select g.id as gym_id, mon::date as month,
       (k ->> 'revenue')::bigint as revenue,
       (k ->> 'active_clients')::int as active_clients,
       (k ->> 'renewal_rate')::numeric as renewal_rate,
       (k ->> 'churn')::int as churn,
       (k ->> 'new_clients')::int as new_clients,
       k -> 'new_by_source' as new_by_source
  from public.gyms g
 cross join lateral generate_series(date_trunc('month', now() at time zone g.timezone) - interval '23 months',
                                    date_trunc('month', now() at time zone g.timezone), interval '1 month') mon
 cross join lateral private.kpi_period(g.id, mon::date, (mon + interval '1 month - 1 day')::date) k
 where private.is_staff(g.id, '{owner,admin}');

-- Средняя загруженность по дням недели и часам за 4 недели
create or replace view public.v_occupancy_hourly with (security_invoker = true) as
select g.id as gym_id, (x ->> 'dow')::int as dow, (x ->> 'hour')::int as hour, (x ->> 'avg')::numeric as avg_people
  from public.gyms g
 cross join lateral jsonb_array_elements(public.gym_occupancy(g.id) -> 'heatmap') x;

-- Выручка по месяцам (для графика на дашборде), быстрый агрегат по оплатам
create or replace function public.revenue_by_month(p_gym uuid, p_months int default 12) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text;
  v_start date;
begin
  perform private.require_staff(p_gym, '{owner,admin}', false);
  select timezone into v_tz from public.gyms where id = p_gym;
  v_start := (date_trunc('month', now() at time zone v_tz) - make_interval(months => p_months - 1))::date;
  return (
    select coalesce(jsonb_agg(jsonb_build_object('month', m.mon::date, 'revenue', coalesce(r.total, 0)) order by m.mon), '[]')
      from generate_series(v_start, (now() at time zone v_tz)::date, interval '1 month') m(mon)
      left join (
        select date_trunc('month', paid_at at time zone v_tz)::date as mon,
               sum(case when refund_of_id is null then amount else -amount end) as total
          from public.payments
         where gym_id = p_gym and paid_at >= v_start::timestamp at time zone v_tz
           and ((refund_of_id is null and status in ('succeeded', 'refunded')) or (refund_of_id is not null and status = 'refunded'))
         group by 1
      ) r on r.mon = m.mon::date
  );
end $$;

-- Итоги журнала оплат за период (FR-6.4)
create or replace function public.payments_summary(p_gym uuid, p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_tz text;
  v_res jsonb;
begin
  perform private.require_staff(p_gym, '{owner,admin}', false);
  select timezone into v_tz from public.gyms where id = p_gym;
  select jsonb_build_object(
           'income', coalesce(sum(amount) filter (where refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'refunds', coalesce(sum(amount) filter (where refund_of_id is not null and status = 'refunded'), 0),
           'cash', coalesce(sum(amount) filter (where method = 'cash' and refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'card', coalesce(sum(amount) filter (where method = 'card' and refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'online', coalesce(sum(amount) filter (where method = 'online' and refund_of_id is null and status in ('succeeded', 'refunded')), 0),
           'count', count(*) filter (where refund_of_id is null and status in ('succeeded', 'refunded')))
    into v_res
    from public.payments
   where gym_id = p_gym
     and paid_at >= p_from::timestamp at time zone v_tz and paid_at < (p_to + 1)::timestamp at time zone v_tz;
  return v_res || jsonb_build_object('net', (v_res ->> 'income')::bigint - (v_res ->> 'refunds')::bigint);
end $$;

-- Счётчик «вернулись» (FR-8.3)
create or replace function public.risk_returned_stats(p_gym uuid, p_from date default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_from timestamptz;
begin
  perform private.require_staff(p_gym, null, false);
  v_from := coalesce(p_from::timestamp at time zone (select timezone from public.gyms where id = p_gym),
                     now() - interval '30 days');
  return (
    select jsonb_build_object('contacted', count(distinct client_id),
                              'returned', count(distinct client_id) filter (where returned_at is not null))
      from public.risk_contacts where gym_id = p_gym and contacted_at >= v_from);
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on all functions in schema public to authenticated, service_role;
revoke execute on function public.confirm_online_payment(text, text, text, text) from authenticated;
revoke execute on function public.attach_provider_payment(uuid, text, text) from authenticated;
revoke execute on function public.confirm_refund(uuid, boolean, text) from authenticated;
revoke execute on function public.run_maintenance() from authenticated;
revoke execute on function public.claim_notifications(int) from authenticated;
revoke execute on function public.complete_notification(uuid, text, text, text) from authenticated;
revoke execute on function public.admin_find_user(text) from authenticated;
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated, service_role;
revoke all on public.v_client_risk, public.v_clients, public.v_in_gym, public.v_gym_kpi_month,
              public.v_occupancy_hourly from anon;
grant select on public.v_client_risk, public.v_clients, public.v_in_gym, public.v_gym_kpi_month,
               public.v_occupancy_hourly to authenticated;

-- ---------------------------------------------------------------------------
-- Расписание фоновых заданий (если установлен pg_cron — как в Supabase)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('core-maintenance-nightly', '5 0 * * *', 'select public.run_maintenance()');
    -- автоматический выход и статусы заморозок — ещё и каждые 15 минут
    perform cron.schedule('core-maintenance-15m', '*/15 * * * *', 'select public.run_maintenance()');
  end if;
exception when others then
  raise notice 'pg_cron недоступен: задания нужно запускать внешним планировщиком (%).', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- Realtime: запись из приложения видна на ресепшене без перезагрузки (приёмка 5.5),
-- «вы в зале» в приложении. Политики RLS действуют и для Realtime.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.bookings, public.visits, public.schedule_items;
  end if;
end $$;

-- ===== supabase/seed.sql
-- Демо-данные core.: зал «Атлет» с историей за 10 месяцев — для локальной разработки, показа и пилотов.
-- Входы (пароль у всех demo12345):
--   owner@demo.core      — владелец
--   admin@demo.core      — администратор
--   reception@demo.core  — ресепшен
--   team@demo.core       — команда core. (суперадмин)
-- Приложение: телефон +7 916 000-00-01 (клиент «Иван Петров»), код из SMS в локальной среде — 123456.

select setseed(0.42);

-- ---------------------------------------------------------------------------
-- Пользователи
-- ---------------------------------------------------------------------------
create or replace function pg_temp.demo_user(p_id uuid, p_email text, p_phone text default null) returns uuid
language plpgsql as $$
begin
  insert into auth.users (instance_id, id, aud, role, email, phone, encrypted_password, email_confirmed_at, phone_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email, p_phone,
          extensions.crypt('demo12345', extensions.gen_salt('bf')), now(), case when p_phone is not null then now() end,
          jsonb_build_object('provider', case when p_email is null then 'phone' else 'email' end,
                             'providers', jsonb_build_array(case when p_email is null then 'phone' else 'email' end)),
          '{}', now(), now(), '', '', '', '')
  on conflict (id) do nothing;
  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (gen_random_uuid(), p_id, p_id::text,
          jsonb_build_object('sub', p_id::text, 'email', p_email, 'phone', p_phone, 'email_verified', true),
          case when p_email is null then 'phone' else 'email' end, now(), now(), now())
  on conflict do nothing;
  return p_id;
end $$;

select pg_temp.demo_user('d0000000-0000-0000-0000-000000000001', 'owner@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000002', 'admin@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000003', 'reception@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-000000000009', 'team@demo.core');
select pg_temp.demo_user('d0000000-0000-0000-0000-0000000000c1', null, '79160000001');
insert into public.platform_admins (user_id) values ('d0000000-0000-0000-0000-000000000009') on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Зал, сотрудники, зоны, тарифы
-- ---------------------------------------------------------------------------
insert into public.gyms (id, name, address, timezone, phone, trial_until, paid_until, onboarded_at, created_at)
values ('d1000000-0000-0000-0000-000000000001', 'Атлет', 'Москва, ул. Спортивная, 12', 'Europe/Moscow', '+74951234567',
        current_date + 14, current_date + 45, now() - interval '300 days', now() - interval '300 days')
on conflict (id) do nothing;

insert into public.staff (gym_id, user_id, email, role, full_name) values
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'owner@demo.core', 'owner', 'Анна Смирнова'),
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000002', 'admin@demo.core', 'admin', 'Олег Кузнецов'),
  ('d1000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000003', 'reception@demo.core', 'reception', 'Катя Морозова')
on conflict do nothing;

insert into public.zones (id, gym_id, name, capacity) values
  ('d2000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'Тренажёрный зал', 60),
  ('d2000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'Студия', 20),
  ('d2000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', 'Сауна', 6)
on conflict do nothing;

insert into public.membership_plans (id, gym_id, name, kind, price, duration_days, visits_limit, freeze_days_max, sold_online, description) values
  ('d3000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'Разовое посещение', 'visits', 60000, 1, 1, 0, true, 'Один визит в течение дня'),
  ('d3000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000001', 'Месяц', 'unlimited', 350000, 30, null, 7, true, 'Безлимит на 30 дней'),
  ('d3000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000001', '8 занятий', 'visits', 280000, 45, 8, 7, true, '8 визитов за 45 дней'),
  ('d3000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000001', '3 месяца', 'unlimited', 900000, 90, null, 14, true, 'Безлимит на 90 дней'),
  ('d3000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000001', 'Утренний', 'period', 250000, 30, null, 7, false, 'До 16:00 по будням')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Клиенты с историей абонементов, оплат и визитов
-- ---------------------------------------------------------------------------
do $$
declare
  g uuid := 'd1000000-0000-0000-0000-000000000001';
  tz text := 'Europe/Moscow';
  today date := (now() at time zone 'Europe/Moscow')::date;
  first_m text[] := array['Иван','Алексей','Дмитрий','Сергей','Андрей','Максим','Артём','Никита','Павел','Егор','Михаил','Роман','Кирилл','Илья','Олег','Денис','Тимур','Глеб'];
  first_f text[] := array['Анна','Мария','Екатерина','Ольга','Наталья','Юлия','Дарья','Алина','Ксения','Полина','Виктория','Елена','София','Вера','Ирина','Татьяна','Алёна','Софья'];
  last_m text[] := array['Иванов','Петров','Сидоров','Смирнов','Кузнецов','Попов','Васильев','Соколов','Михайлов','Новиков','Фёдоров','Морозов','Волков','Алексеев','Лебедев','Семёнов','Егоров','Павлов','Козлов','Степанов','Николаев','Орлов','Андреев','Макаров','Никитин','Захаров'];
  sources text[] := array['Instagram','Instagram','Рекомендация','Рекомендация','Рекомендация','Яндекс Карты','2ГИС','Вывеска','ВКонтакте','Сайт'];
  plans uuid[] := array['d3000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002','d3000000-0000-0000-0000-000000000002',
                        'd3000000-0000-0000-0000-000000000003','d3000000-0000-0000-0000-000000000004','d3000000-0000-0000-0000-000000000005']::uuid[];
  i int;
  c uuid;
  female boolean;
  name text;
  joined date;
  d date;
  pl public.membership_plans;
  pick uuid;
  m uuid;
  loyalty numeric;
  weekly numeric;
  fading boolean;
  ends date;
  v_day date;
  ts timestamptz;
  hour int;
  vleft int;
  method public.payment_method;
  status public.membership_status;
begin
  if exists (select 1 from public.clients where gym_id = g) then return; end if;
  for i in 1..320 loop
    female := random() < 0.52;
    name := case when female
      then last_m[1 + floor(random() * array_length(last_m, 1))::int] || 'а ' || first_f[1 + floor(random() * array_length(first_f, 1))::int]
      else last_m[1 + floor(random() * array_length(last_m, 1))::int] || ' ' || first_m[1 + floor(random() * array_length(first_m, 1))::int] end;
    joined := today - (1 + floor(random() * 290))::int;
    if i = 1 then name := 'Петров Иван'; female := false; joined := today - 200; end if;
    insert into public.clients (gym_id, full_name, phone, email, gender, source, tags, consent_pd_at, consent_pd_text,
                                consent_marketing_at, consent_marketing_text, created_at, user_id)
    values (g, name, '+7916' || lpad(i::text, 7, '0'),
            case when random() < 0.4 then 'client' || i || '@mail.ru' end,
            case when female then 'female' else 'male' end,
            sources[1 + floor(random() * array_length(sources, 1))::int],
            case when random() < 0.15 then array['утро'] when random() < 0.1 then array['vip'] else '{}' end,
            joined::timestamp at time zone tz, 'Согласие получено на ресепшене (демо)',
            case when random() < 0.7 then joined::timestamp at time zone tz end,
            'Согласие на рассылки (демо)', joined::timestamp at time zone tz,
            case when i = 1 then 'd0000000-0000-0000-0000-0000000000c1'::uuid end)
    returning id into c;

    loyalty := 0.55 + random() * 0.4;          -- вероятность продления
    weekly := 1.2 + random() * 2.6;            -- визитов в неделю
    fading := random() < 0.08;                 -- в последние недели стал ходить реже
    d := joined;
    m := null;
    loop
      pick := plans[1 + floor(random() * array_length(plans, 1))::int];
      select * into pl from public.membership_plans where id = pick;
      ends := d + pl.duration_days - 1;
      status := case when ends < today then 'expired' else 'active' end;
      method := (array['card','card','cash','online'])[1 + floor(random() * 4)::int]::public.payment_method;
      insert into public.memberships (gym_id, client_id, plan_id, plan_name, kind, starts_on, ends_on, visits_left,
                                      freeze_days_max, status, price_paid, renewed_from_id, created_at)
      values (g, c, pl.id, pl.name, pl.kind, d, ends, pl.visits_limit, pl.freeze_days_max, status, pl.price, m,
              (d::timestamp + time '10:00' + make_interval(mins => floor(random() * 600)::int)) at time zone tz)
      returning id into m;
      insert into public.payments (gym_id, client_id, membership_id, amount, method, status, provider, paid_at, created_at, description)
      values (g, c, m, pl.price, method, 'succeeded', case when method = 'online' then 'yookassa' end,
              (d::timestamp + time '10:00' + make_interval(mins => floor(random() * 600)::int)) at time zone tz,
              (d::timestamp + time '10:00') at time zone tz, 'Абонемент «' || pl.name || '»');

      -- визиты в период действия
      vleft := coalesce(pl.visits_limit, 1000);
      v_day := d;
      while v_day <= least(ends, today) and vleft > 0 loop
        if random() < ((weekly / 7.0) * (case when fading and v_day > today - 14 then 0.15 else 1 end)) then
          hour := case when random() < 0.3 then 7 + floor(random() * 4)::int
                       when random() < 0.75 then 17 + floor(random() * 5)::int
                       else 11 + floor(random() * 6)::int end;
          if pl.name = 'Утренний' then hour := 7 + floor(random() * 8)::int; end if;
          ts := (v_day::timestamp + make_interval(hours => hour, mins => floor(random() * 60)::int)) at time zone tz;
          if ts < now() - interval '2 hours' then
            insert into public.visits (gym_id, client_id, membership_id, checked_in_at, checked_out_at, method)
            values (g, c, m, ts, ts + make_interval(mins => 50 + floor(random() * 60)::int),
                    case when random() < 0.6 then 'qr' else 'manual' end::public.visit_method);
            vleft := vleft - 1;
          end if;
        end if;
        v_day := v_day + 1;
      end loop;
      if pl.visits_limit is not null then
        update public.memberships set visits_left = greatest(vleft, 0) where id = m;
      end if;

      exit when ends >= today;
      exit when random() > loyalty;                       -- не продлил
      d := ends + 1 + case when random() < 0.25 then floor(random() * 10)::int else 0 end;
      exit when d > today;
    end loop;
  end loop;

  update public.clients cl set last_visit_at = v.mx
    from (select client_id, max(checked_in_at) mx from public.visits where gym_id = g group by client_id) v
   where v.client_id = cl.id;

  -- сейчас в зале
  insert into public.visits (gym_id, client_id, membership_id, checked_in_at, method)
  select g, m2.client_id, m2.id, now() - make_interval(mins => floor(random() * 80)::int), 'qr'
    from public.memberships m2
   where m2.gym_id = g and m2.status = 'active' and m2.starts_on <= today and m2.ends_on >= today and m2.kind <> 'visits'
   order by random() limit 14;

  -- несколько заморозок и контактов из списка риска
  insert into public.freezes (gym_id, membership_id, from_date, to_date, reason)
  select g, m3.id, today - 2, today + 5, 'отпуск'
    from public.memberships m3
   where m3.gym_id = g and m3.status = 'active' and m3.freeze_days_max >= 8 and m3.starts_on < today - 3 and m3.ends_on > today + 10
   order by random() limit 4;
  update public.memberships m4 set ends_on = ends_on + 8, freeze_days_used = 8, status = 'frozen'
   where exists (select 1 from public.freezes f where f.membership_id = m4.id);
end $$;

-- ---------------------------------------------------------------------------
-- Расписание на 4 недели: групповые занятия и записи
-- ---------------------------------------------------------------------------
do $$
declare
  g uuid := 'd1000000-0000-0000-0000-000000000001';
  tz text := 'Europe/Moscow';
  monday date := date_trunc('week', (now() at time zone 'Europe/Moscow'))::date - 7;
  s record;
  d date;
  item uuid;
begin
  if exists (select 1 from public.schedule_items where gym_id = g) then return; end if;
  for s in select * from (values
      ('Йога', 'Ольга', 1, '19:00'::time, 60, 16, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Йога', 'Ольга', 3, '19:00'::time, 60, 16, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Функциональный тренинг', 'Максим', 2, '20:00'::time, 55, 14, 'd2000000-0000-0000-0000-000000000001'::uuid),
      ('Функциональный тренинг', 'Максим', 4, '20:00'::time, 55, 14, 'd2000000-0000-0000-0000-000000000001'::uuid),
      ('Пилатес', 'Ника', 6, '11:00'::time, 55, 12, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Бокс', 'Тимур', 5, '19:30'::time, 60, 12, 'd2000000-0000-0000-0000-000000000001'::uuid),
      ('Стретчинг', 'Ольга', 7, '12:00'::time, 50, 16, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Утренняя растяжка', 'Ника', 2, '08:00'::time, 45, 10, 'd2000000-0000-0000-0000-000000000002'::uuid),
      ('Утренняя растяжка', 'Ника', 4, '08:00'::time, 45, 10, 'd2000000-0000-0000-0000-000000000002'::uuid)
    ) t(title, trainer, dow, at_time, minutes, cap, zone) loop
    for w in 0..3 loop
      d := monday + w * 7 + s.dow - 1;
      insert into public.schedule_items (gym_id, kind, title, zone_id, trainer_name, starts_at, ends_at, capacity, recurrence_rule)
      values (g, 'class', s.title, s.zone, s.trainer, (d + s.at_time) at time zone tz,
              (d + s.at_time + make_interval(mins => s.minutes)) at time zone tz, s.cap, 'FREQ=WEEKLY')
      returning id into item;
      insert into public.bookings (gym_id, schedule_item_id, client_id, status, channel)
      select g, item, cl.id,
             case when (d + s.at_time) at time zone tz < now() then (case when random() < 0.85 then 'attended' else 'no_show' end)::public.booking_status
                  else 'booked' end,
             case when random() < 0.45 then 'app' else 'staff' end::public.booking_channel
        from public.clients cl
       where cl.gym_id = g and exists (select 1 from public.memberships mm where mm.client_id = cl.id and mm.status in ('active', 'frozen'))
       order by random()
       limit (s.cap * (0.4 + random() * 0.6))::int;
    end loop;
  end loop;
  -- персональные тренировки и сауна
  insert into public.schedule_items (gym_id, kind, title, zone_id, trainer_name, starts_at, ends_at, capacity)
  select g, 'personal', 'Персональная тренировка', 'd2000000-0000-0000-0000-000000000001', 'Максим',
         ((monday + 7 + n) + time '17:00') at time zone tz, ((monday + 7 + n) + time '18:00') at time zone tz, 1
    from generate_series(0, 4) n;
  insert into public.schedule_items (gym_id, kind, title, zone_id, starts_at, ends_at, capacity)
  select g, 'zone_slot', 'Сауна', 'd2000000-0000-0000-0000-000000000003',
         ((monday + 7 + n) + time '20:00') at time zone tz, ((monday + 7 + n) + time '21:30') at time zone tz, 6
    from generate_series(0, 6) n;
end $$;

-- Отметки контакта по части клиентов «в зоне риска» (для счётчика «вернулись»)
insert into public.risk_contacts (gym_id, client_id, reason, channel, note, contacted_at)
select r.gym_id, r.client_id, r.reason, (array['call','whatsapp','telegram'])[1 + floor(random() * 3)::int], 'демо', now() - interval '3 days'
  from public.v_client_risk r
 where r.gym_id = 'd1000000-0000-0000-0000-000000000001'
 order by random() limit 8
on conflict do nothing;
update public.risk_contacts set returned_at = now() - interval '1 day'
 where id in (select id from public.risk_contacts order by random() limit 3);

-- Статусы по датам
select public.run_maintenance();
