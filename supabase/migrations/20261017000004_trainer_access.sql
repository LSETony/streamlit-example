-- Доступ тренера: видит клиентов, расписание и записи, отмечает «пришёл / не пришёл».
-- Не продаёт абонементы, не отмечает визиты на ресепшене, не видит оплаты и настройки.

alter table public.schedule_items add column trainer_staff_id uuid references public.staff(id) on delete set null;
create index schedule_items_trainer_idx on public.schedule_items(trainer_staff_id) where trainer_staff_id is not null;

-- Права по умолчанию: запись без явного списка ролей — владелец, администратор и ресепшен (не тренер)
create or replace function private.require_staff(p_gym uuid, p_roles public.staff_role[] default null,
                                                 p_write boolean default true) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare
  v_id uuid;
  v_roles public.staff_role[] := coalesce(p_roles, case when p_write then '{owner,admin,reception}'::public.staff_role[] end);
begin
  select id into v_id from public.staff
   where gym_id = p_gym and user_id = auth.uid() and active
     and (v_roles is null or role = any (v_roles));
  if v_id is null then
    perform private.fail('FORBIDDEN', 'Недостаточно прав для этого действия');
  end if;
  if p_write and not private.gym_writable(p_gym) then
    if exists (select 1 from public.gyms where id = p_gym and is_demo) then
      perform private.fail('DEMO_READ_ONLY', 'Это демо-кабинет: изменения отключены');
    end if;
    perform private.fail('GYM_READ_ONLY', 'Пробный период закончился: кабинет работает в режиме «только чтение»');
  end if;
  return v_id;
end $$;

-- Клиентов создают и меняют владелец, администратор и ресепшен
drop policy clients_insert on public.clients;
drop policy clients_update on public.clients;
create policy clients_insert on public.clients for insert to authenticated
  with check (private.is_staff(gym_id, '{owner,admin,reception}') and private.gym_writable(gym_id) and deleted_at is null);
create policy clients_update on public.clients for update to authenticated
  using (private.is_staff(gym_id, '{owner,admin,reception}') and private.gym_writable(gym_id) and deleted_at is null)
  with check (private.is_staff(gym_id, '{owner,admin,reception}'));

-- «Пришёл / не пришёл» отмечает и тренер
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
  perform private.require_staff(v_gym, '{owner,admin,reception,trainer}');
  update public.bookings set status = p_status where id = p_booking and status <> 'cancelled';
end $$;

-- Занятие можно назначить сотруднику-тренеру: имя подставляется из его профиля
drop function if exists public.create_schedule_series(uuid, text, timestamp, int, int, public.schedule_kind, uuid, text, int[], date, text);
create or replace function public.create_schedule_series(
  p_gym uuid, p_title text, p_starts_local timestamp, p_duration_min int,
  p_capacity int default 10, p_kind public.schedule_kind default 'class', p_zone uuid default null,
  p_trainer text default null, p_weekdays int[] default null, p_until date default null,
  p_description text default null, p_trainer_staff uuid default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_tz text;
  v_series uuid;
  v_rule text;
  v_day date;
  v_count int := 0;
  v_until date;
  v_trainer text := p_trainer;
begin
  perform private.require_staff(p_gym, '{owner,admin}');
  perform private.require_feature(p_gym, 'schedule');
  if p_duration_min <= 0 then perform private.fail('INVALID_DURATION', 'Длительность должна быть больше нуля'); end if;
  select timezone into v_tz from public.gyms where id = p_gym;
  if p_trainer_staff is not null then
    select full_name into v_trainer from public.staff where id = p_trainer_staff and gym_id = p_gym and role = 'trainer' and active;
    if v_trainer is null then perform private.fail('TRAINER_NOT_FOUND', 'Тренер не найден'); end if;
  end if;

  if p_weekdays is null or cardinality(p_weekdays) = 0 then
    insert into public.schedule_items (gym_id, kind, title, description, zone_id, trainer_name, trainer_staff_id, starts_at, ends_at, capacity)
    values (p_gym, p_kind, p_title, p_description, p_zone, v_trainer, p_trainer_staff,
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
      insert into public.schedule_items (gym_id, kind, title, description, zone_id, trainer_name, trainer_staff_id, starts_at, ends_at,
                                         capacity, recurrence_rule, series_id)
      values (p_gym, p_kind, p_title, p_description, p_zone, v_trainer, p_trainer_staff,
              (v_day + p_starts_local::time) at time zone v_tz,
              (v_day + p_starts_local::time + make_interval(mins => p_duration_min)) at time zone v_tz,
              p_capacity, v_rule, v_series);
      v_count := v_count + 1;
    end if;
  end loop;
  return jsonb_build_object('created', v_count, 'series_id', v_series, 'rule', v_rule);
end $$;

revoke execute on function public.create_schedule_series(uuid, text, timestamp, int, int, public.schedule_kind, uuid, text, int[], date, text, uuid) from public, anon;
grant execute on function public.create_schedule_series(uuid, text, timestamp, int, int, public.schedule_kind, uuid, text, int[], date, text, uuid) to authenticated, service_role;
grant execute on function private.require_staff(uuid, public.staff_role[], boolean) to authenticated, service_role;
