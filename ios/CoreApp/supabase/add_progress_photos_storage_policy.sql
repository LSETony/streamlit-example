-- Fixes "uploadProgressPhoto: StorageError(statusCode: 403, message: "new
-- row violates row-level security policy")" when a member adds a Progress
-- Photo. Every other piece of media in this app (hero video, workout
-- photos, gym photos, recipe photos) was uploaded straight to the "media"
-- bucket by the developer via the Supabase dashboard, which uses the
-- service role and bypasses RLS — Progress Photos is the first upload the
-- app itself performs with the anon key, and no storage.objects policy
-- has ever allowed the anon key to write to this bucket, only to read
-- from it (bucket-level "public" only covers reads).
--
-- Matches this app's existing device-scoped trust model (see
-- AppState+Supabase.swift's doc comment): the anon key can write any
-- object, scoping is enforced client-side by always writing under
-- progress/<device_user_id>/..., not by cryptographic RLS, since there's
-- no Supabase Auth session to key off. Run once in the Supabase SQL
-- Editor — safe to re-run.
drop policy if exists "Progress photos upload" on storage.objects;
create policy "Progress photos upload" on storage.objects
  for insert
  to anon
  with check (bucket_id = 'media' and name like 'progress/%');
