-- Веб-приложение клиента и публичный виджет записи: расписание со свободными местами без персональных данных.
-- Записи других клиентов скрыты RLS, поэтому количество занятых мест отдаёт отдельная функция.

-- Карточка зала для виджета на сайте: название, контакты, валюта и действующие тарифы
create or replace function public.public_gym(p_gym uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', g.id, 'name', g.name, 'address', g.address, 'phone', g.phone, 'logo_url', g.logo_url,
    'region', g.region, 'currency', g.currency, 'timezone', g.timezone,
    'schedule', coalesce((public.gym_features(g.id) ->> 'schedule')::boolean, false),
    'plans', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'description', p.description, 'kind', p.kind,
                                          'price', p.price, 'duration_days', p.duration_days,
                                          'visits_limit', p.visits_limit) order by p.price)
        from public.membership_plans p where p.gym_id = g.id and p.active), '[]'))
    from public.gyms g where g.id = p_gym
$$;

-- Ближайшие групповые занятия: занято мест и, для вошедшего клиента зала, его запись
create or replace function public.public_schedule(p_gym uuid, p_days int default 14) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', s.id, 'title', s.title, 'description', s.description, 'trainer_name', s.trainer_name,
           'zone', z.name, 'starts_at', s.starts_at, 'ends_at', s.ends_at, 'capacity', s.capacity,
           'booked', (select count(*) from public.bookings b
                       where b.schedule_item_id = s.id and b.status in ('booked', 'attended')),
           'my_booking_id', (select b.id from public.bookings b join public.clients c on c.id = b.client_id
                              where b.schedule_item_id = s.id and b.status = 'booked'
                                and c.user_id = auth.uid() and auth.uid() is not null and c.deleted_at is null
                              limit 1)
         ) order by s.starts_at), '[]')
    from public.schedule_items s
    left join public.zones z on z.id = s.zone_id
   where s.gym_id = p_gym and s.kind = 'class' and not s.cancelled
     and s.starts_at > now() and s.starts_at < now() + make_interval(days => least(greatest(p_days, 1), 31))
     and coalesce((public.gym_features(p_gym) ->> 'schedule')::boolean, false)
$$;

revoke execute on function public.public_gym(uuid) from public;
revoke execute on function public.public_schedule(uuid, int) from public;
grant execute on function public.public_gym(uuid) to anon, authenticated, service_role;
grant execute on function public.public_schedule(uuid, int) to anon, authenticated, service_role;
