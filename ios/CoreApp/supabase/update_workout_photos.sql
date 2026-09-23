-- Swaps in real gym photos (from LSETony's own footage) for workout cards
-- that were using a reused/generic image. Safe to re-run anytime — each
-- run just updates the rows listed below. Run in Supabase SQL Editor
-- after add_more_workouts.sql has already been run once.

update public.workout_cards set image_name = 'WorkoutGymCandid1' where id = 'b0000000-0000-4000-8000-000000000005';

-- Real video for the same card, uploaded to Supabase Storage — plays
-- muted/looping as the workout detail screen's hero background.
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6388422-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000005';

-- Second real video, for "Cardio Kickstart" (still uses the bundled
-- WorkoutBodyWeight photo as its poster/fallback until the video loads).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6388429-uhd_2160_3840_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000006';

-- Third real video, for "Core Basics" (bundled WorkoutPrentalFlow photo
-- stays as its poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6388436-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000007';

-- Fourth real video, for "Flexibility & Mobility" (bundled
-- WorkoutChestTriceps photo stays as its poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389571-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000008';

-- Fifth real video, for "Leg Day Burner" (Top 10 workouts section;
-- bundled WorkoutBeginnerFemale photo stays as its poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389575-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000009';

-- Sixth real video, for "HIIT Cardio Blast" (bundled WorkoutBodyWeight
-- photo stays as its poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389576-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000010';

-- Seventh real video, for "Back and Biceps" (bundled WorkoutPrentalFlow
-- photo stays as its poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389823-uhd_2160_3840_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000011';

-- Eighth real video, for "Full Body Circuit" — the last of the 8 new
-- cards, all now have a real video (bundled WorkoutChestTriceps photo
-- stays as its poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389826-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000012';

-- Ninth real video, now for one of the original 4 cards: "Beginner
-- Female Aesthetics" (bundled WorkoutBeginnerFemale photo stays as its
-- poster/fallback).
update public.workout_cards set video_url = 'https://ubykgrowhekmsvxhvjxf.supabase.co/storage/v1/object/public/media/6389827-uhd_3840_2160_25fps.mp4' where id = 'b0000000-0000-4000-8000-000000000001';
