-- Backs a real, live "how full is the gym right now" reading. The
-- occupancy percent/headcount were previously just a hardcoded shape
-- curve sampled against the clock — not sourced from any actual
-- activity. This table logs one row per check-in (every reception QR
-- scan, every completed in-app workout — see AppState+Growth.swift's
-- recordActivity()/recordCheckIn()), and "currently in the club" is
-- read as the count of distinct members whose most recent check-in
-- falls within the last couple of hours — there's no check-out event
-- in this app, so a time window stands in for one.
--
-- Same device-scoped trust model as every other table here (see
-- schema.sql's comment on booked_sessions/cart_items): anon key,
-- scoped client-side by device_user_id, not by Supabase Auth. Safe to
-- re-run.

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  device_user_id text not null,
  checked_in_at timestamptz not null default now()
);

create index if not exists checkins_checked_in_at_idx on public.checkins (checked_in_at);

alter table public.checkins enable row level security;

-- Public read is what makes a live, club-wide occupancy count possible —
-- every device needs to see every other device's recent check-ins to
-- compute "how many people are here now", not just its own.
drop policy if exists "Public read" on public.checkins;
create policy "Public read" on public.checkins for select using (true);

drop policy if exists "Anon insert" on public.checkins;
create policy "Anon insert" on public.checkins for insert to anon with check (true);
