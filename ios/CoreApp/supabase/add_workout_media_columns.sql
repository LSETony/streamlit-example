-- Adds image_url/video_url to workout_cards for real Supabase Storage
-- media, replacing bundled app assets. Run once in the Supabase SQL
-- Editor — safe to re-run (IF NOT EXISTS guards it).
alter table public.workout_cards add column if not exists image_url text;
alter table public.workout_cards add column if not exists video_url text;
