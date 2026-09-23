-- Swaps in real gym photos (from LSETony's own footage) for workout cards
-- that were using a reused/generic image. Safe to re-run anytime — each
-- run just updates the rows listed below. Run in Supabase SQL Editor
-- after add_more_workouts.sql has already been run once.

update public.workout_cards set image_name = 'WorkoutGymCandid1' where id = 'b0000000-0000-4000-8000-000000000005';
