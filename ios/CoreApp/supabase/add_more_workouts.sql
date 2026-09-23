-- Adds more variety to Workouts > Beginner's Plan and Top 10 workouts,
-- which previously only had 2 cards each. Run this once in the Supabase
-- SQL Editor (Project -> SQL Editor -> New query), after schema.sql has
-- already been run. Reuses the 4 existing workout photos (no new image
-- assets needed) — each card is still distinct by title/level/duration/
-- category/exercises.

insert into public.workout_cards (id, section, image_name, title, level, duration, category) values
('b0000000-0000-4000-8000-000000000005', 'beginner_plan', 'WorkoutGymCandid1', 'Full Body Foundations', 'Beginner', '7 day', 'Strength'),
('b0000000-0000-4000-8000-000000000006', 'beginner_plan', 'WorkoutBodyWeight', 'Cardio Kickstart', 'Beginner', '7 day', 'Cardio'),
('b0000000-0000-4000-8000-000000000007', 'beginner_plan', 'WorkoutPrentalFlow', 'Core Basics', 'Beginner', '10 day', 'Strength'),
('b0000000-0000-4000-8000-000000000008', 'beginner_plan', 'WorkoutChestTriceps', 'Flexibility & Mobility', 'Beginner', '5 day', 'Cardio'),
('b0000000-0000-4000-8000-000000000009', 'top_workouts', 'WorkoutBeginnerFemale', 'Leg Day Burner', 'Inter', '30 mins', 'Strength'),
('b0000000-0000-4000-8000-000000000010', 'top_workouts', 'WorkoutBodyWeight', 'HIIT Cardio Blast', 'Inter', '20 mins', 'Cardio'),
('b0000000-0000-4000-8000-000000000011', 'top_workouts', 'WorkoutPrentalFlow', 'Back and Biceps', 'Inter', '25 mins', 'Strength'),
('b0000000-0000-4000-8000-000000000012', 'top_workouts', 'WorkoutChestTriceps', 'Full Body Circuit', 'Advanced', '35 mins', 'Cardio');

insert into public.exercises (workout_card_id, name, icon, sets, reps, sort_order) values
('b0000000-0000-4000-8000-000000000005', 'Goblet Squats', 'figure.strengthtraining.functional', 3, '12', 0),
('b0000000-0000-4000-8000-000000000005', 'Push-ups', 'figure.strengthtraining.traditional', 3, '10', 1),
('b0000000-0000-4000-8000-000000000005', 'Bent-over Rows', 'figure.strengthtraining.functional', 3, '12', 2),
('b0000000-0000-4000-8000-000000000005', 'Plank', 'figure.core.training', 3, '30 sec', 3),

('b0000000-0000-4000-8000-000000000006', 'Jumping Jacks', 'figure.jumprope', 3, '40 sec', 0),
('b0000000-0000-4000-8000-000000000006', 'High Knees', 'figure.run', 3, '30 sec', 1),
('b0000000-0000-4000-8000-000000000006', 'Butt Kicks', 'figure.run', 3, '30 sec', 2),
('b0000000-0000-4000-8000-000000000006', 'Mountain Climbers', 'figure.highintensity.intervaltraining', 3, '20', 3),

('b0000000-0000-4000-8000-000000000007', 'Dead Bug', 'figure.core.training', 3, '12', 0),
('b0000000-0000-4000-8000-000000000007', 'Bird Dog', 'figure.core.training', 3, '10', 1),
('b0000000-0000-4000-8000-000000000007', 'Russian Twists', 'figure.core.training', 3, '20', 2),
('b0000000-0000-4000-8000-000000000007', 'Plank', 'figure.core.training', 3, '40 sec', 3),

('b0000000-0000-4000-8000-000000000008', 'Cat-Cow Stretch', 'figure.flexibility', 3, '10', 0),
('b0000000-0000-4000-8000-000000000008', 'Hip Flexor Stretch', 'figure.flexibility', 3, '30 sec', 1),
('b0000000-0000-4000-8000-000000000008', 'Shoulder Rolls', 'figure.flexibility', 3, '10', 2),

('b0000000-0000-4000-8000-000000000009', 'Barbell Squats', 'figure.strengthtraining.functional', 4, '10', 0),
('b0000000-0000-4000-8000-000000000009', 'Walking Lunges', 'figure.walk', 3, '12', 1),
('b0000000-0000-4000-8000-000000000009', 'Leg Press', 'figure.strengthtraining.functional', 3, '12', 2),
('b0000000-0000-4000-8000-000000000009', 'Calf Raises', 'figure.strengthtraining.functional', 3, '15', 3),

('b0000000-0000-4000-8000-000000000010', 'Burpees', 'figure.highintensity.intervaltraining', 4, '15', 0),
('b0000000-0000-4000-8000-000000000010', 'Jump Squats', 'figure.highintensity.intervaltraining', 4, '15', 1),
('b0000000-0000-4000-8000-000000000010', 'Mountain Climbers', 'figure.highintensity.intervaltraining', 4, '30 sec', 2),
('b0000000-0000-4000-8000-000000000010', 'Sprint in Place', 'figure.run', 4, '30 sec', 3),

('b0000000-0000-4000-8000-000000000011', 'Pull-ups', 'figure.strengthtraining.traditional', 4, '8', 0),
('b0000000-0000-4000-8000-000000000011', 'Barbell Rows', 'figure.strengthtraining.functional', 4, '10', 1),
('b0000000-0000-4000-8000-000000000011', 'Bicep Curls', 'figure.strengthtraining.traditional', 3, '12', 2),
('b0000000-0000-4000-8000-000000000011', 'Hammer Curls', 'figure.strengthtraining.traditional', 3, '12', 3),

('b0000000-0000-4000-8000-000000000012', 'Kettlebell Swings', 'figure.strengthtraining.functional', 4, '15', 0),
('b0000000-0000-4000-8000-000000000012', 'Box Jumps', 'figure.highintensity.intervaltraining', 4, '10', 1),
('b0000000-0000-4000-8000-000000000012', 'Battle Ropes', 'figure.cross.training', 4, '30 sec', 2),
('b0000000-0000-4000-8000-000000000012', 'Rowing Sprint', 'figure.rower', 4, '30 sec', 3);
