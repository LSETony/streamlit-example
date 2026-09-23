-- Populates the Home hero's video pool and the gym photo strip with the
-- real clips/photos that don't map to a specific workout card. Safe to
-- re-run — upserts by key. Run after add_app_settings.sql.

insert into public.app_settings (key, value) values
('hero_video_urls', 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389834-uhd_3840_2160_25fps.mp4,https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389835-uhd_3840_2160_25fps.mp4,https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6390150-uhd_2160_3840_25fps.mp4,https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6390152-uhd_3840_2160_25fps.mp4,https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6390153-uhd_2160_3840_25fps.mp4'),
('gym_photo_urls', 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/pexels-tima-miroshnichenko-6389869.jpg')
on conflict (key) do update set value = excluded.value;
