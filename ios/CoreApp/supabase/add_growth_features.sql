-- Backs the new streak/check-in/referral/leaderboard/progress-photo
-- features: member_stats is the server-side source of truth for visit
-- count and streak (so it's shared across every device this member signs
-- into, not just kept in local UserDefaults), progress_photos holds the
-- before/after gallery. Same trust model as booked_sessions/cart_items
-- (anon key, scoped client-side by device_user_id) — see schema.sql's
-- comment on those tables for why. Safe to re-run.

create table if not exists public.member_stats (
  device_user_id text primary key,
  display_name text not null default 'Member',
  total_visits int not null default 0,
  current_streak int not null default 0,
  last_activity_date date,
  referral_code text unique,
  referred_by text,
  created_at timestamptz not null default now()
);

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  device_user_id text not null,
  image_url text not null,
  taken_at timestamptz not null default now()
);

alter table public.member_stats enable row level security;
alter table public.progress_photos enable row level security;

-- Public read on member_stats is what makes the leaderboard possible —
-- every device can see every other device's display name/visits/streak,
-- nothing more sensitive than that lives in this table.
drop policy if exists "Public read" on public.member_stats;
create policy "Public read" on public.member_stats for select using (true);

drop policy if exists "Anon full access" on public.member_stats;
create policy "Anon full access" on public.member_stats for all using (true) with check (true);

drop policy if exists "Anon full access" on public.progress_photos;
create policy "Anon full access" on public.progress_photos for all using (true) with check (true);
