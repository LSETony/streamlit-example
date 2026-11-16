-- ИИ-агенты зала.
-- Встроенные агенты работают в core. (Claude), внешние подключаются по API-ключу (REST или MCP).
-- Агент действует от имени сотрудника, который его настроил (владелец или администратор), — значит,
-- через те же проверки прав, что и в кабинете, и никогда не шире его прав. Если этот сотрудник
-- уволен или стал ресепшеном, агент останавливается.
-- Для каждого инструмента задаётся режим: off — выключен, approve — действие ждёт подтверждения
-- сотрудника в очереди, auto — агент выполняет сам. Чтение данных — off или auto.

create table public.ai_agents (
  id           uuid primary key default gen_random_uuid(),
  gym_id       uuid not null references public.gyms(id) on delete cascade,
  name         text not null check (length(trim(name)) between 1 and 80),
  kind         text not null check (kind in ('builtin', 'external')),
  template     text not null default 'custom',
  instructions text not null default '' check (length(instructions) <= 8000),
  task         text not null default '' check (length(task) <= 4000),   -- задание для запуска по расписанию
  tools        jsonb not null default '{}',
  schedule     text not null default 'off' check (schedule in ('off', 'daily')),
  enabled      boolean not null default true,
  acts_as      uuid references auth.users(id) on delete set null,     -- от чьего имени действует
  last_run_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index ai_agents_gym_idx on public.ai_agents(gym_id);

create table public.ai_agent_keys (
  id           uuid primary key default gen_random_uuid(),
  gym_id       uuid not null references public.gyms(id) on delete cascade,
  agent_id     uuid not null references public.ai_agents(id) on delete cascade,
  prefix       text not null,                 -- первые символы ключа, чтобы узнать его в списке
  key_hash     text not null unique,          -- sha256 ключа; сам ключ не хранится
  created_at   timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at   timestamptz
);

create table public.ai_agent_runs (
  id            uuid primary key default gen_random_uuid(),
  gym_id        uuid not null references public.gyms(id) on delete cascade,
  agent_id      uuid not null references public.ai_agents(id) on delete cascade,
  source        text not null check (source in ('manual', 'schedule')),
  prompt        text not null,
  output        text,
  steps         jsonb not null default '[]',
  status        text not null default 'running' check (status in ('running', 'done', 'failed')),
  error         text,
  input_tokens  int not null default 0,
  output_tokens int not null default 0,
  created_by    uuid,
  created_at    timestamptz not null default now(),
  finished_at   timestamptz
);
create index ai_agent_runs_agent_idx on public.ai_agent_runs(agent_id, created_at desc);

create table public.ai_agent_actions (
  id          uuid primary key default gen_random_uuid(),
  gym_id      uuid not null references public.gyms(id) on delete cascade,
  agent_id    uuid not null references public.ai_agents(id) on delete cascade,
  run_id      uuid references public.ai_agent_runs(id) on delete set null,
  tool        text not null,
  args        jsonb not null default '{}',
  reason      text,                          -- зачем агент это делает — показывается в очереди
  status      text not null check (status in ('pending', 'running', 'executed', 'rejected', 'failed')),
  result      jsonb,
  error       text,
  decided_by  uuid,
  decided_at  timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index ai_agent_actions_gym_idx on public.ai_agent_actions(gym_id, created_at desc);
create index ai_agent_actions_pending_idx on public.ai_agent_actions(gym_id) where status = 'pending';

create trigger ai_agents_touch before update on public.ai_agents
  for each row execute function private.touch_updated_at();
create trigger ai_agent_actions_touch before update on public.ai_agent_actions
  for each row execute function private.touch_updated_at();

alter table public.ai_agents        enable row level security;
alter table public.ai_agent_keys    enable row level security;
alter table public.ai_agent_runs    enable row level security;
alter table public.ai_agent_actions enable row level security;

create policy ai_agents_select on public.ai_agents for select to authenticated
  using (private.is_staff(gym_id, '{owner,admin}'));
create policy ai_agent_keys_select on public.ai_agent_keys for select to authenticated
  using (private.is_staff(gym_id, '{owner,admin}'));
create policy ai_agent_runs_select on public.ai_agent_runs for select to authenticated
  using (private.is_staff(gym_id, '{owner,admin}'));
create policy ai_agent_actions_select on public.ai_agent_actions for select to authenticated
  using (private.is_staff(gym_id, '{owner,admin}'));
-- изменения только через функции ниже
revoke insert, update, delete on public.ai_agents, public.ai_agent_keys, public.ai_agent_runs, public.ai_agent_actions
  from authenticated, anon;
-- хеш ключа сотрудникам не отдаём
revoke select on public.ai_agent_keys from authenticated, anon;
grant select (id, gym_id, agent_id, prefix, created_at, last_used_at, revoked_at) on public.ai_agent_keys to authenticated;

-- Каталог инструментов: read — только чтение, write — меняет данные или пишет клиенту
create or replace function private.ai_tool_kinds() returns jsonb
language sql immutable as $$
  select '{"find_clients":"read","risk_clients":"read","client_details":"read","schedule":"read","gym_stats":"read",
           "log_contact":"write","send_push":"write","send_whatsapp":"write","book_class":"write",
           "cancel_booking":"write","freeze_membership":"write","add_client_note":"write"}'::jsonb
$$;

-- Действующая настройка инструмента для агента: off | approve | auto
create or replace function private.ai_tool_mode(a public.ai_agents, p_tool text) returns text
language sql stable as $$
  select case when private.ai_tool_kinds() ? p_tool then coalesce(a.tools ->> p_tool, 'off') else 'off' end
$$;

-- Создать или изменить агента. Сохранивший становится тем, от чьего имени агент действует.
create or replace function public.ai_agent_save(p_gym uuid, p_agent uuid, p_name text, p_kind text, p_template text,
                                                p_instructions text, p_task text, p_tools jsonb, p_schedule text,
                                                p_enabled boolean)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_tools jsonb := '{}';
  v_count int;
  k text;
  v text;
begin
  perform private.require_staff(p_gym, '{owner,admin}');
  if coalesce(trim(p_name), '') = '' then perform private.fail('INVALID_INPUT', 'Укажите название агента'); end if;
  if p_kind not in ('builtin', 'external') then perform private.fail('INVALID_INPUT', 'Неизвестный тип агента'); end if;
  for k, v in select key, value #>> '{}' from jsonb_each(coalesce(p_tools, '{}')) loop
    if not private.ai_tool_kinds() ? k then perform private.fail('INVALID_INPUT', 'Неизвестный инструмент: ' || k); end if;
    if v not in ('off', 'approve', 'auto') or (private.ai_tool_kinds() ->> k = 'read' and v = 'approve') then
      perform private.fail('INVALID_INPUT', 'Недопустимый режим инструмента: ' || k);
    end if;
    if v <> 'off' then v_tools := v_tools || jsonb_build_object(k, v); end if;
  end loop;
  if p_agent is null then
    select count(*) into v_count from public.ai_agents where gym_id = p_gym;
    if v_count >= 20 then perform private.fail('AGENT_LIMIT', 'В зале уже 20 агентов. Удалите ненужного'); end if;
    insert into public.ai_agents (gym_id, name, kind, template, instructions, task, tools, schedule, enabled, acts_as)
    values (p_gym, trim(p_name), p_kind, coalesce(p_template, 'custom'), coalesce(p_instructions, ''), coalesce(p_task, ''),
            v_tools, coalesce(p_schedule, 'off'), coalesce(p_enabled, true), auth.uid())
    returning id into v_id;
  else
    update public.ai_agents
       set name = trim(p_name), template = coalesce(p_template, template), instructions = coalesce(p_instructions, ''),
           task = coalesce(p_task, ''), tools = v_tools, schedule = coalesce(p_schedule, 'off'),
           enabled = coalesce(p_enabled, true), acts_as = auth.uid()
     where id = p_agent and gym_id = p_gym
    returning id into v_id;
    if v_id is null then perform private.fail('AGENT_NOT_FOUND', 'Агент не найден'); end if;
  end if;
  return v_id;
end $$;

create or replace function public.ai_agent_delete(p_agent uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
begin
  select gym_id into v_gym from public.ai_agents where id = p_agent;
  if v_gym is null then perform private.fail('AGENT_NOT_FOUND', 'Агент не найден'); end if;
  perform private.require_staff(v_gym, '{owner,admin}', false);
  delete from public.ai_agents where id = p_agent;
end $$;

-- Выпустить ключ для внешнего агента. Ключ показывается один раз; в базе — только его хеш.
create or replace function public.ai_agent_create_key(p_agent uuid) returns text
language plpgsql security definer set search_path = public as $$
declare
  a public.ai_agents;
  v_key text := 'core_ak_' || encode(extensions.gen_random_bytes(24), 'hex');
begin
  select * into a from public.ai_agents where id = p_agent;
  if a.id is null then perform private.fail('AGENT_NOT_FOUND', 'Агент не найден'); end if;
  perform private.require_staff(a.gym_id, '{owner,admin}');
  if (select count(*) from public.ai_agent_keys where agent_id = a.id and revoked_at is null) >= 5 then
    perform private.fail('KEY_LIMIT', 'У агента уже 5 действующих ключей. Отзовите ненужный');
  end if;
  insert into public.ai_agent_keys (gym_id, agent_id, prefix, key_hash)
  values (a.gym_id, a.id, left(v_key, 14), encode(extensions.digest(v_key, 'sha256'), 'hex'));
  return v_key;
end $$;

create or replace function public.ai_agent_revoke_key(p_key uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_gym uuid;
begin
  select gym_id into v_gym from public.ai_agent_keys where id = p_key;
  if v_gym is null then perform private.fail('KEY_NOT_FOUND', 'Ключ не найден'); end if;
  perform private.require_staff(v_gym, '{owner,admin}', false);
  update public.ai_agent_keys set revoked_at = coalesce(revoked_at, now()) where id = p_key;
end $$;

-- Агент по ключу (для API). Только для сервера платформы.
create or replace function public.ai_agent_by_key(p_key text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  a public.ai_agents;
begin
  update public.ai_agent_keys set last_used_at = now()
   where key_hash = encode(extensions.digest(coalesce(p_key, ''), 'sha256'), 'hex') and revoked_at is null
  returning agent_id into v_id;
  select * into a from public.ai_agents where id = v_id;
  if a.id is null then perform private.fail('UNAUTHORIZED', 'Неверный или отозванный ключ агента'); end if;
  return to_jsonb(a);
end $$;

-- Инструменты. Работают от имени текущего пользователя (auth.uid()): это сотрудник, подтвердивший
-- действие, или сотрудник, от имени которого действует агент (см. agent_tool). Все объекты
-- проверяются на принадлежность залу p_gym — даже если у пользователя есть и другие залы.
create or replace function private.ai_run_tool(p_gym uuid, p_tool text, p_args jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_limit int := least(greatest(coalesce((p_args ->> 'limit')::int, 20), 1), 100);
  v_q text := trim(coalesce(p_args ->> 'query', ''));
  v_digits text;
  v_client uuid;
  v_result jsonb;
  c public.clients;
begin
  if not private.is_staff(p_gym, '{owner,admin}') then
    perform private.fail('FORBIDDEN', 'Недостаточно прав для этого действия');
  end if;
  if p_args ? 'client_id' then
    v_client := (p_args ->> 'client_id')::uuid;
    select * into c from public.clients where id = v_client and gym_id = p_gym and deleted_at is null;
    if c.id is null then perform private.fail('CLIENT_NOT_FOUND', 'Клиент не найден'); end if;
  end if;

  case p_tool
  when 'find_clients' then
    v_digits := regexp_replace(v_q, '\D', '', 'g');
    select coalesce(jsonb_agg(jsonb_build_object(
             'client_id', v.id, 'full_name', v.full_name, 'phone', v.phone, 'email', v.email, 'tags', v.tags,
             'membership_state', v.membership_state, 'plan_name', v.plan_name,
             'membership_ends_on', v.membership_ends_on, 'visits_left', v.visits_left,
             'last_visit_at', v.last_visit_at, 'in_app', v.in_app)), '[]')
      into v_result
      from (select * from public.v_clients
             where gym_id = p_gym
               and (v_q = '' or full_name ilike '%' || v_q || '%' or email ilike '%' || v_q || '%'
                    or (length(v_digits) >= 4 and regexp_replace(coalesce(phone, ''), '\D', '', 'g') like '%' || v_digits || '%'))
             order by last_visit_at desc nulls last limit v_limit) v;
  when 'risk_clients' then
    select coalesce(jsonb_agg(jsonb_build_object(
             'client_id', r.client_id, 'full_name', r.full_name, 'phone', r.phone, 'reason', r.reason,
             'reason_text', r.reason_text, 'membership_id', r.membership_id,
             'membership_ends_on', r.membership_ends_on, 'last_visit_at', r.last_visit_at,
             'in_app', r.in_app, 'marketing_consent', r.marketing_ok,
             'contacted_at', r.contacted_at, 'contact_channel', r.contact_channel)), '[]')
      into v_result
      from (select * from public.v_client_risk
             where gym_id = p_gym and (p_args ->> 'reason' is null or reason = p_args ->> 'reason')
               and (coalesce((p_args ->> 'include_contacted')::boolean, false) or contacted_at is null)
             order by urgency desc limit v_limit) r;
  when 'client_details' then
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
    select jsonb_build_object(
      'client_id', c.id, 'full_name', c.full_name, 'phone', c.phone, 'email', c.email, 'tags', c.tags,
      'note', c.note, 'in_app', c.user_id is not null, 'marketing_consent', c.consent_marketing_at is not null,
      'last_visit_at', c.last_visit_at, 'client_since', c.created_at,
      'memberships', (select coalesce(jsonb_agg(jsonb_build_object(
          'membership_id', m.id, 'plan_name', m.plan_name, 'status', m.status, 'starts_on', m.starts_on,
          'ends_on', m.ends_on, 'visits_left', m.visits_left,
          'freeze_days_left', greatest(m.freeze_days_max - m.freeze_days_used, 0)) order by m.ends_on desc), '[]')
        from (select * from public.memberships where client_id = c.id order by ends_on desc limit 10) m),
      'recent_visits', (select coalesce(jsonb_agg(v.checked_in_at order by v.checked_in_at desc), '[]')
        from (select checked_in_at from public.visits where client_id = c.id order by checked_in_at desc limit 10) v),
      'bookings', (select coalesce(jsonb_agg(jsonb_build_object('booking_id', b.id, 'class', s.title,
                                                                'starts_at', s.starts_at, 'status', b.status)
                                             order by s.starts_at), '[]')
        from public.bookings b join public.schedule_items s on s.id = b.schedule_item_id
       where b.client_id = c.id and s.starts_at > now() - interval '1 day' and b.status = 'booked'),
      'contacts', (select coalesce(jsonb_agg(jsonb_build_object('at', r.contacted_at, 'channel', r.channel,
                                                                'reason', r.reason, 'note', r.note)
                                             order by r.contacted_at desc), '[]')
        from (select * from public.risk_contacts where client_id = c.id order by contacted_at desc limit 5) r))
      into v_result;
  when 'schedule' then
    select coalesce(jsonb_agg(jsonb_build_object(
             'class_id', s ->> 'id', 'title', s ->> 'title', 'trainer', s ->> 'trainer_name', 'zone', s ->> 'zone',
             'starts_at', s ->> 'starts_at', 'ends_at', s ->> 'ends_at',
             'free_spots', (s ->> 'capacity')::int - (s ->> 'booked')::int)), '[]')
      into v_result
      from jsonb_array_elements(public.public_schedule(p_gym, coalesce((p_args ->> 'days')::int, 7))) s;
  when 'gym_stats' then
    v_result := public.dashboard_kpi(p_gym);
  when 'log_contact' then
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
    if coalesce(p_args ->> 'channel', 'other') not in ('call', 'telegram', 'whatsapp', 'other') then
      perform private.fail('INVALID_INPUT', 'Недопустимый канал связи');
    end if;
    v_result := jsonb_build_object('contact_id', public.mark_contacted(v_client, coalesce(p_args ->> 'reason', 'ai_agent'),
      coalesce(p_args ->> 'channel', 'other'), p_args ->> 'note', null));
  when 'send_push' then
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
    if coalesce(trim(p_args ->> 'text'), '') = '' then perform private.fail('INVALID_INPUT', 'Укажите текст сообщения'); end if;
    v_result := jsonb_build_object('contact_id', public.mark_contacted(v_client, coalesce(p_args ->> 'reason', 'ai_agent'),
      'push', 'Push от ИИ-агента', left(p_args ->> 'text', 500)));
  when 'send_whatsapp' then
    -- само сообщение отправляет сервер платформы: stage=check — проверка перед отправкой, stage=log — запись контакта
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
    if c.consent_marketing_at is null then perform private.fail('NO_MARKETING_CONSENT', 'Клиент не давал согласия на рассылки'); end if;
    if c.phone is null then perform private.fail('NO_PHONE', 'У клиента не указан телефон'); end if;
    perform private.require_staff(p_gym, '{owner,admin}');
    if p_args ->> 'stage' = 'log' then
      v_result := jsonb_build_object('contact_id', public.mark_contacted(v_client, coalesce(p_args ->> 'reason', 'ai_agent'),
        'whatsapp', 'WhatsApp Business · ИИ-агент', null));
    else
      v_result := jsonb_build_object('ok', true);
    end if;
  when 'book_class' then
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
    if not exists (select 1 from public.schedule_items where id = (p_args ->> 'class_id')::uuid and gym_id = p_gym) then
      perform private.fail('CLASS_NOT_FOUND', 'Занятие не найдено');
    end if;
    v_result := public.book_class((p_args ->> 'class_id')::uuid, v_client);
  when 'cancel_booking' then
    if not exists (select 1 from public.bookings where id = (p_args ->> 'booking_id')::uuid and gym_id = p_gym) then
      perform private.fail('BOOKING_NOT_FOUND', 'Запись не найдена');
    end if;
    v_result := public.cancel_booking((p_args ->> 'booking_id')::uuid);
  when 'freeze_membership' then
    if not exists (select 1 from public.memberships where id = (p_args ->> 'membership_id')::uuid and gym_id = p_gym) then
      perform private.fail('MEMBERSHIP_NOT_FOUND', 'Абонемент не найден');
    end if;
    v_result := to_jsonb(public.freeze_membership((p_args ->> 'membership_id')::uuid, (p_args ->> 'from')::date,
                                                   (p_args ->> 'to')::date, coalesce(p_args ->> 'reason', 'ИИ-агент')));
  when 'add_client_note' then
    if v_client is null then perform private.fail('CLIENT_REQUIRED', 'Укажите клиента'); end if;
    if coalesce(trim(p_args ->> 'note'), '') = '' then perform private.fail('INVALID_INPUT', 'Укажите текст заметки'); end if;
    perform private.require_staff(p_gym, '{owner,admin}');
    update public.clients
       set note = left(concat_ws(E'\n', nullif(note, ''), to_char(now() at time zone 'UTC', 'YYYY-MM-DD') || ' · ИИ-агент: ' || trim(p_args ->> 'note')), 4000)
     where id = v_client;
    v_result := jsonb_build_object('ok', true);
  else
    perform private.fail('UNKNOWN_TOOL', 'Неизвестный инструмент');
  end case;
  return coalesce(v_result, 'null'::jsonb);
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
  perform private.fail('INVALID_INPUT', 'Неверный формат параметров');
end $$;

-- Инструмент от имени агента. Только для сервера платформы (service_role): подменяет пользователя
-- на сотрудника, настроившего агента, в пределах этой транзакции.
create or replace function public.agent_tool(p_agent uuid, p_tool text, p_args jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  a public.ai_agents;
begin
  select * into a from public.ai_agents where id = p_agent;
  if a.id is null then perform private.fail('AGENT_NOT_FOUND', 'Агент не найден'); end if;
  if not a.enabled then perform private.fail('AGENT_DISABLED', 'Агент выключен'); end if;
  if private.ai_tool_mode(a, p_tool) = 'off' then
    perform private.fail('TOOL_DISABLED', 'Этот инструмент агенту не разрешён');
  end if;
  if a.acts_as is null or not exists (select 1 from public.staff where gym_id = a.gym_id and user_id = a.acts_as
                                         and active and role in ('owner', 'admin')) then
    perform private.fail('AGENT_OWNER_GONE', 'Сотрудник, настроивший агента, больше не владелец или администратор. Сохраните агента заново');
  end if;
  perform set_config('request.jwt.claim.sub', a.acts_as::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub', a.acts_as, 'role', 'authenticated')::text, true);
  perform set_config('core.ai_agent', a.name, true);
  return private.ai_run_tool(a.gym_id, p_tool, coalesce(p_args, '{}'));
end $$;

-- Очередь подтверждения: сотрудник берёт действие в работу, выполняет (от своего имени) и закрывает
create or replace function public.ai_action_claim(p_action uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  x public.ai_agent_actions;
begin
  select * into x from public.ai_agent_actions where id = p_action for update;
  if x.id is null then perform private.fail('ACTION_NOT_FOUND', 'Действие не найдено'); end if;
  perform private.require_staff(x.gym_id, '{owner,admin}');
  if x.status <> 'pending' then perform private.fail('ACTION_DECIDED', 'Действие уже обработано'); end if;
  update public.ai_agent_actions set status = 'running', decided_by = auth.uid(), decided_at = now()
   where id = x.id returning * into x;
  return to_jsonb(x);
end $$;

create or replace function public.ai_action_finish(p_action uuid, p_ok boolean, p_result jsonb default null,
                                                   p_error text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.ai_agent_actions
     set status = case when p_ok then 'executed' else 'failed' end, result = p_result, error = left(p_error, 1000)
   where id = p_action and status = 'running' and decided_by = auth.uid();
  if not found then perform private.fail('ACTION_NOT_FOUND', 'Действие не найдено'); end if;
end $$;

create or replace function public.ai_action_reject(p_action uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  x public.ai_agent_actions;
begin
  select * into x from public.ai_agent_actions where id = p_action for update;
  if x.id is null then perform private.fail('ACTION_NOT_FOUND', 'Действие не найдено'); end if;
  perform private.require_staff(x.gym_id, '{owner,admin}', false);
  if x.status <> 'pending' then perform private.fail('ACTION_DECIDED', 'Действие уже обработано'); end if;
  update public.ai_agent_actions set status = 'rejected', decided_by = auth.uid(), decided_at = now() where id = x.id;
end $$;

-- Подтверждённое действие сотрудник выполняет от своего имени
create or replace function public.ai_tool(p_gym uuid, p_tool text, p_args jsonb default '{}') returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  return private.ai_run_tool(p_gym, p_tool, coalesce(p_args, '{}'));
end $$;

-- В журнале изменений видно, что изменение сделал ИИ-агент
create or replace function private.audit_trigger() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_diff jsonb;
  v_gym uuid := coalesce((v_new ->> 'gym_id')::uuid, (v_old ->> 'gym_id')::uuid);
  v_id uuid := coalesce((v_new ->> 'id')::uuid, (v_old ->> 'id')::uuid);
  v_agent text := nullif(current_setting('core.ai_agent', true), '');
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
  if v_agent is not null then v_diff := v_diff || jsonb_build_object('_ai_agent', v_agent); end if;
  insert into public.audit_log (gym_id, actor_user_id, action, entity, entity_id, diff)
  values (v_gym, auth.uid(), lower(tg_op), tg_table_name, v_id, v_diff);
  return coalesce(new, old);
end $$;

revoke execute on function private.ai_run_tool(uuid, text, jsonb) from public;
revoke execute on function public.ai_agent_save(uuid, uuid, text, text, text, text, text, jsonb, text, boolean),
                           public.ai_agent_delete(uuid), public.ai_agent_create_key(uuid), public.ai_agent_revoke_key(uuid),
                           public.ai_action_claim(uuid), public.ai_action_finish(uuid, boolean, jsonb, text),
                           public.ai_action_reject(uuid), public.ai_tool(uuid, text, jsonb),
                           public.ai_agent_by_key(text), public.agent_tool(uuid, text, jsonb)
  from public, anon;
grant execute on function public.ai_agent_save(uuid, uuid, text, text, text, text, text, jsonb, text, boolean),
                          public.ai_agent_delete(uuid), public.ai_agent_create_key(uuid), public.ai_agent_revoke_key(uuid),
                          public.ai_action_claim(uuid), public.ai_action_finish(uuid, boolean, jsonb, text),
                          public.ai_action_reject(uuid), public.ai_tool(uuid, text, jsonb)
  to authenticated, service_role;
grant execute on function public.ai_agent_by_key(text), public.agent_tool(uuid, text, jsonb) to service_role;
revoke execute on function public.ai_agent_by_key(text), public.agent_tool(uuid, text, jsonb) from authenticated;
grant select, insert, update on public.ai_agent_runs, public.ai_agent_actions to service_role;
grant select, update on public.ai_agents to service_role;
