-- The original 4 workout cards now show real gym video frames instead of
-- their old bundled stock photos, and their old titles (gendered /
-- pregnancy-specific) don't match generic gym footage anymore.
update public.workout_cards set title = 'Strength Starter' where id = 'b0000000-0000-4000-8000-000000000001';
update public.workout_cards set title = 'Mobility Flow' where id = 'b0000000-0000-4000-8000-000000000003';
