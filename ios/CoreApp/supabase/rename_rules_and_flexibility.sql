-- Two small fixes for an already-seeded database:
-- 1. "Gym Safety" -> "Rules" (matches the app's Important card + the
--    Workouts screen's title check for opening the rules sheet).
-- 2. "Flexibility & Mobility" recategorized from Cardio to its own
--    Flexibility category, now that Workouts has a Flexibility filter.
update public.important_cards set title = 'Rules' where title = 'Gym Safety';
update public.workout_cards set category = 'Flexibility' where id = 'b0000000-0000-4000-8000-000000000008';
