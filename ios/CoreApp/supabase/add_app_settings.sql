-- Small global key/value config table for things like the Home hero's
-- video pool. Run once in the Supabase SQL Editor.
create table if not exists public.app_settings (
  key text primary key,
  value text not null
);

alter table public.app_settings enable row level security;

drop policy if exists "Public read" on public.app_settings;
create policy "Public read" on public.app_settings for select using (true);
