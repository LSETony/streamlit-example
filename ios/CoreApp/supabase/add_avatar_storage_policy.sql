-- Lets the app upload a member's chosen profile photo to the shared
-- "media" Storage bucket under avatars/<device_user_id>/... — mirrors
-- add_progress_photos_storage_policy.sql's reasoning exactly (no
-- storage.objects policy has ever allowed the anon key to write outside
-- the paths explicitly opened up here; every other object in this
-- bucket was uploaded by the developer via the dashboard, which bypasses
-- RLS). INSERT-only, same as progress photos: AppState.uploadAvatarPhoto
-- writes a fresh filename each time rather than overwriting, so no
-- UPDATE policy is needed. Run once in the Supabase SQL Editor — safe to
-- re-run.
drop policy if exists "Avatar upload" on storage.objects;
create policy "Avatar upload" on storage.objects
  for insert
  to anon
  with check (bucket_id = 'media' and name like 'avatars/%');
