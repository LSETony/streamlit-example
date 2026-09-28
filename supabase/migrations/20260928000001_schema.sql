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
