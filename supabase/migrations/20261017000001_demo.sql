-- Публичное демо: залы с флагом is_demo открываются в один клик и работают только на чтение,
-- поэтому проверяющие и потенциальные клиенты не могут ничего изменить или сломать.

alter table public.gyms add column is_demo boolean not null default false;

create or replace function private.gym_writable(p_gym uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.gyms g
     where g.id = p_gym
       and not g.is_demo
       and (g.trial_until >= current_date or coalesce(g.paid_until, date '1900-01-01') >= current_date)
  )
$$;

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
    if exists (select 1 from public.gyms where id = p_gym and is_demo) then
      perform private.fail('DEMO_READ_ONLY', 'Это демо-кабинет: изменения отключены');
    end if;
    perform private.fail('GYM_READ_ONLY', 'Пробный период закончился: кабинет работает в режиме «только чтение»');
  end if;
  return v_id;
end $$;

grant execute on function private.gym_writable(uuid) to authenticated, service_role;
grant execute on function private.require_staff(uuid, public.staff_role[], boolean) to authenticated, service_role;
