-- ============================================================
-- core. — Supabase schema + seed data
--
-- Run once in Supabase Dashboard → SQL Editor → New query → Run.
-- Safe to re-run: tables use IF NOT EXISTS, policies are dropped and
-- recreated, and the seed section truncates + re-inserts catalog rows
-- (booked_sessions / cart_items, which hold real member data, are left
-- untouched by re-runs).
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Tables ----------

create table if not exists public.trainers (
  id uuid primary key default gen_random_uuid(),
  image_name text not null,
  name text not null,
  specialty text not null,
  rating text not null,
  reviews integer not null,
  price_label text not null,
  price_compact text not null,
  next_available text not null,
  availability_color text not null,
  years_experience text not null,
  clients integer not null,
  sessions integer not null,
  tags text[] not null default '{}',
  bio text not null
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  abbr text not null,
  name text not null,
  form text not null,
  dose text not null,
  count text not null,
  price integer not null,
  subscription_price integer not null,
  tag text not null,
  tag_color text not null,
  description text not null,
  benefits text not null,
  risks text not null,
  interactions text not null
);

create table if not exists public.product_ingredients (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name text not null,
  amount text not null,
  sort_order integer not null default 0
);

create table if not exists public.workout_cards (
  id uuid primary key default gen_random_uuid(),
  section text not null check (section in ('beginner_plan', 'top_workouts')),
  image_name text not null,
  title text not null,
  level text not null,
  duration text not null,
  category text not null,
  -- Real photo/video uploaded to Supabase Storage — overrides image_name
  -- (a bundled app asset) when set. Nullable: most cards still just use
  -- image_name.
  image_url text,
  video_url text
);

create table if not exists public.exercises (
  id uuid primary key default gen_random_uuid(),
  workout_card_id uuid not null references public.workout_cards(id) on delete cascade,
  name text not null,
  icon text not null,
  sets integer not null,
  reps text not null,
  sort_order integer not null default 0
);

create table if not exists public.important_cards (
  id uuid primary key default gen_random_uuid(),
  icon text not null,
  title text not null,
  subtitle text not null
);

create table if not exists public.food_recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price integer not null,
  ingredients text[] not null default '{}'
);

create table if not exists public.gym_zones (
  id uuid primary key default gen_random_uuid(),
  icon text not null,
  name text not null,
  subtitle text not null,
  capacity integer not null
);

-- Small global key/value config table. Currently just holds
-- 'hero_video_urls' — a comma-separated list of Supabase Storage video
-- URLs the Home screen picks one from at random to loop behind the hero
-- photo, so extra uploaded gym clips that don't map to a specific
-- workout card still get used somewhere.
create table if not exists public.app_settings (
  key text primary key,
  value text not null
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price integer not null,
  period text not null,
  perks text[] not null default '{}',
  recommended boolean not null default false
);

-- Scoped by device_user_id, not auth.uid(): the app's Apple/Google/phone
-- sign-in doesn't create a Supabase Auth session, so there's no auth.uid()
-- to key RLS off. Each install keeps a random UUID in UserDefaults
-- (DeviceUser.id in SupabaseService.swift) and every query/write filters
-- on it client-side.
create table if not exists public.booked_sessions (
  id uuid primary key,
  device_user_id text not null,
  date timestamptz not null,
  title text not null,
  trainer_name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.cart_items (
  id uuid primary key,
  device_user_id text not null,
  name text not null,
  price integer not null,
  created_at timestamptz not null default now()
);

-- ---------- Row Level Security ----------

alter table public.trainers enable row level security;
alter table public.products enable row level security;
alter table public.product_ingredients enable row level security;
alter table public.workout_cards enable row level security;
alter table public.exercises enable row level security;
alter table public.important_cards enable row level security;
alter table public.food_recipes enable row level security;
alter table public.gym_zones enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.app_settings enable row level security;
alter table public.booked_sessions enable row level security;
alter table public.cart_items enable row level security;

drop policy if exists "Public read" on public.trainers;
create policy "Public read" on public.trainers for select using (true);

drop policy if exists "Public read" on public.products;
create policy "Public read" on public.products for select using (true);

drop policy if exists "Public read" on public.product_ingredients;
create policy "Public read" on public.product_ingredients for select using (true);

drop policy if exists "Public read" on public.workout_cards;
create policy "Public read" on public.workout_cards for select using (true);

drop policy if exists "Public read" on public.exercises;
create policy "Public read" on public.exercises for select using (true);

drop policy if exists "Public read" on public.important_cards;
create policy "Public read" on public.important_cards for select using (true);

drop policy if exists "Public read" on public.food_recipes;
create policy "Public read" on public.food_recipes for select using (true);

drop policy if exists "Public read" on public.gym_zones;
create policy "Public read" on public.gym_zones for select using (true);

drop policy if exists "Public read" on public.subscription_plans;
create policy "Public read" on public.subscription_plans for select using (true);

drop policy if exists "Public read" on public.app_settings;
create policy "Public read" on public.app_settings for select using (true);

-- Demo-level policy: no Supabase Auth session exists to check auth.uid()
-- against (see the comment on booked_sessions above), so the anon key is
-- allowed full access and scoping happens client-side. Tighten this to
-- auth.uid()-based policies once the app adopts Supabase Auth for sign-in.
drop policy if exists "Anon full access" on public.booked_sessions;
create policy "Anon full access" on public.booked_sessions for all using (true) with check (true);

drop policy if exists "Anon full access" on public.cart_items;
create policy "Anon full access" on public.cart_items for all using (true) with check (true);

-- ---------- Seed data ----------

truncate table
  public.product_ingredients,
  public.products,
  public.exercises,
  public.workout_cards,
  public.important_cards,
  public.food_recipes,
  public.gym_zones,
  public.subscription_plans,
  public.trainers;

insert into public.trainers (image_name, name, specialty, rating, reviews, price_label, price_compact, next_available, availability_color, years_experience, clients, sessions, tags, bio) values
('Trainer1', 'Arina Ivolga', 'Personal trainer', '4.9', 212, '$45/h', '45', 'Today', 'success', '9 years', 48, 1840,
 array['Squat mechanics','Peaking blocks','Return to lifting'],
 'Coaches the strength floor and writes the club''s barbell progressions. Works with lifters coming back from long breaks and with members chasing a first 2× bodyweight squat.'),
('Trainer2', 'Daniil Orlov', 'Personal trainer', '4.8', 134, '$40/h', '40', 'Mon', 'accent', '6 years', 35, 1320,
 array['HIIT','Fat loss','Functional training'],
 'Builds high-intensity, functional programs for members chasing fat loss and conditioning rather than pure strength numbers.'),
('Trainer3', 'Marco Fedele', 'Personal trainer', '4.9', 156, '$50/h', '50', 'Thu', 'success', '10 years', 44, 1680,
 array['Strength','Powerlifting','Hypertrophy'],
 'Strength-focused coaching built around progressive overload — works with members chasing real numbers on the big lifts.'),
('Trainer4', 'Elena Marchetti', 'Personal trainer', '4.8', 121, '$46/h', '46', 'Fri', 'accent', '7 years', 39, 1450,
 array['Conditioning','HIIT','Core strength'],
 'High-energy conditioning sessions built around circuits and core work — popular with members training for endurance events.');

insert into public.products (id, abbr, name, form, dose, count, price, subscription_price, tag, tag_color, description, benefits, risks, interactions) values
('a0000000-0000-4000-8000-000000000001', 'B', 'B-Complex', 'Capsule', '50 mg', '90 capsules', 54, 46, 'In protocol', 'accent',
 'A full spread of B vitamins for energy metabolism and nervous-system support through heavy training blocks.',
 'Supports energy release from food and reduces fatigue during high training volume.',
 'Generally well tolerated. High-dose B6 over long periods can cause nerve tingling — stay within label dose.',
 'Can interfere with some Parkinson''s and epilepsy medications — check with a doctor if you take either.'),
('a0000000-0000-4000-8000-000000000002', 'Cr', 'Creatine monohydrate', 'Powder', '5 g', '500 g', 150, 128, 'Recommended', 'success',
 'Creapure monohydrate. The most studied performance supplement there is; no loading phase needed.',
 'Adds a few reps at a given load and roughly 1–2 kg of water inside the muscle.',
 'Safe in healthy adults at 3–5 g. Drink enough water; kidney disease is the one contraindication.',
 'No meaningful drug interactions. Caffeine does not cancel it, despite the old claim.'),
('a0000000-0000-4000-8000-000000000003', 'Zn', 'Zinc picolinate', 'Capsule', '15 mg', '100 capsules', 35, 30, 'Watch dose', 'warning',
 'A 15 mg dose, deliberately lower than the 50 mg tubs sold elsewhere.',
 'Covers a genuine gap in low-meat diets and supports immune function.',
 'Above 40 mg daily for months depletes copper and can cause anaemia.',
 'Competes with iron — four hours apart. Also reduces absorption of some antibiotics.'),
('a0000000-0000-4000-8000-000000000004', 'Mg', 'Magnesium', 'Capsule', '400 mg', '120 capsules', 85, 72, 'In protocol', 'accent',
 'The sleep-and-recovery magnesium. Glycinate is well absorbed and does not act as a laxative at this dose.',
 'Shortens time to sleep and reduces cramping in heavy training weeks.',
 'Loose stools above 600 mg. Anyone with reduced kidney function should ask a doctor first.',
 'Blunts absorption of tetracycline and quinolone antibiotics, and of bisphosphonates. Separate by two hours.');

insert into public.product_ingredients (product_id, name, amount, sort_order) values
('a0000000-0000-4000-8000-000000000001', 'Vitamin B6', '10 mg', 0),
('a0000000-0000-4000-8000-000000000001', 'Vitamin B12', '500 mcg', 1),
('a0000000-0000-4000-8000-000000000001', 'Folate', '400 mcg', 2),
('a0000000-0000-4000-8000-000000000002', 'Creatine monohydrate', '5 000 mg', 0),
('a0000000-0000-4000-8000-000000000003', 'Zinc (picolinate)', '15 mg', 0),
('a0000000-0000-4000-8000-000000000003', 'Copper (gluconate)', '1 mg', 1),
('a0000000-0000-4000-8000-000000000004', 'Magnesium (glycinate)', '400 mg', 0),
('a0000000-0000-4000-8000-000000000004', 'Glycine', '1 200 mg', 1);

insert into public.workout_cards (id, section, image_name, title, level, duration, category) values
('b0000000-0000-4000-8000-000000000001', 'beginner_plan', 'WorkoutBeginnerFemale', 'Strength Starter', 'Beginner', '7 day', 'Strength'),
('b0000000-0000-4000-8000-000000000002', 'beginner_plan', 'WorkoutBodyWeight', 'Beginner Body Weight Plan', 'Beginner', '7 day', 'Cardio'),
('b0000000-0000-4000-8000-000000000003', 'top_workouts', 'WorkoutPrentalFlow', 'Mobility Flow', 'Beginner', '22 mins', 'Strength'),
('b0000000-0000-4000-8000-000000000004', 'top_workouts', 'WorkoutChestTriceps', 'Chest and Triceps', 'Inter', '22 mins', 'Strength');

insert into public.exercises (workout_card_id, name, icon, sets, reps, sort_order) values
('b0000000-0000-4000-8000-000000000001', 'Bodyweight Squats', 'figure.strengthtraining.functional', 3, '15', 0),
('b0000000-0000-4000-8000-000000000001', 'Glute Bridges', 'figure.core.training', 3, '15', 1),
('b0000000-0000-4000-8000-000000000001', 'Knee Push-ups', 'figure.strengthtraining.traditional', 3, '10', 2),
('b0000000-0000-4000-8000-000000000001', 'Plank', 'figure.core.training', 3, '30 sec', 3),
('b0000000-0000-4000-8000-000000000001', 'Lunges', 'figure.walk', 3, '12', 4),
('b0000000-0000-4000-8000-000000000001', 'Bicycle Crunches', 'figure.core.training', 3, '20', 5),
('b0000000-0000-4000-8000-000000000002', 'Jumping Jacks', 'figure.jumprope', 3, '30 sec', 0),
('b0000000-0000-4000-8000-000000000002', 'Push-ups', 'figure.strengthtraining.traditional', 3, '10', 1),
('b0000000-0000-4000-8000-000000000002', 'Squats', 'figure.strengthtraining.functional', 3, '15', 2),
('b0000000-0000-4000-8000-000000000002', 'Mountain Climbers', 'figure.highintensity.intervaltraining', 3, '20', 3),
('b0000000-0000-4000-8000-000000000002', 'Plank', 'figure.core.training', 3, '30 sec', 4),
('b0000000-0000-4000-8000-000000000003', 'Cat-Cow Stretch', 'figure.flexibility', 3, '10', 0),
('b0000000-0000-4000-8000-000000000003', 'Pelvic Tilts', 'figure.flexibility', 3, '12', 1),
('b0000000-0000-4000-8000-000000000003', 'Wall Push-ups', 'figure.strengthtraining.traditional', 3, '10', 2),
('b0000000-0000-4000-8000-000000000003', 'Side-Lying Leg Lifts', 'figure.core.training', 3, '12', 3),
('b0000000-0000-4000-8000-000000000003', 'Seated Marching', 'figure.walk', 3, '15', 4),
('b0000000-0000-4000-8000-000000000003', 'Deep Breathing', 'figure.mind.and.body', 3, '1 min', 5),
('b0000000-0000-4000-8000-000000000004', 'Push-ups', 'figure.strengthtraining.traditional', 4, '12', 0),
('b0000000-0000-4000-8000-000000000004', 'Dumbbell Bench Press', 'dumbbell.fill', 4, '10', 1),
('b0000000-0000-4000-8000-000000000004', 'Tricep Dips', 'figure.strengthtraining.traditional', 3, '12', 2),
('b0000000-0000-4000-8000-000000000004', 'Overhead Tricep Extension', 'dumbbell.fill', 3, '12', 3),
('b0000000-0000-4000-8000-000000000004', 'Chest Fly', 'dumbbell.fill', 3, '12', 4),
('b0000000-0000-4000-8000-000000000004', 'Close-Grip Push-ups', 'figure.strengthtraining.traditional', 3, '10', 5);

-- More Beginner's Plan / Top 10 workouts cards so the Workouts feed has
-- real variety to scroll through (reuses the 4 existing photos above —
-- distinct per card by title/level/duration/category/exercises).
insert into public.workout_cards (id, section, image_name, title, level, duration, category) values
('b0000000-0000-4000-8000-000000000005', 'beginner_plan', 'WorkoutGymCandid1', 'Full Body Foundations', 'Beginner', '7 day', 'Strength'),
('b0000000-0000-4000-8000-000000000006', 'beginner_plan', 'WorkoutBodyWeight', 'Cardio Kickstart', 'Beginner', '7 day', 'Cardio'),
('b0000000-0000-4000-8000-000000000007', 'beginner_plan', 'WorkoutPrentalFlow', 'Core Basics', 'Beginner', '10 day', 'Strength'),
('b0000000-0000-4000-8000-000000000008', 'beginner_plan', 'WorkoutChestTriceps', 'Flexibility & Mobility', 'Beginner', '5 day', 'Flexibility'),
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

insert into public.important_cards (icon, title, subtitle) values
('shield.fill', 'Rules', 'Rules & equipment guide'),
('party.popper.fill', 'Events', 'What''s on this month');

insert into public.food_recipes (name, price, ingredients) values
('Chicken Cajun', 9, array['Chicken breast','Cajun spice','Olive oil','Bell pepper']),
('Protein pancakes', 6, array['Whey protein','Egg','Banana','Oats']),
('Beef Jerky', 12, array['Beef','Soy sauce','Black pepper','Garlic powder']),
('Carnivore Soup', 10, array['Beef bone broth','Beef chunks','Salt','Egg']);

insert into public.gym_zones (icon, name, subtitle, capacity) values
('figure.pilates', 'Pilates Studio', 'Reformer & mat sessions', 8),
('figure.run', 'Running Track', 'Indoor treadmill lane', 12),
('dumbbell.fill', 'Free Weights Floor', 'Barbells, racks & benches', 20),
('flame.fill', 'Sauna & Recovery', 'Steam room & sauna', 6);

insert into public.subscription_plans (name, price, period, perks, recommended) values
('Basic', 39, 'mo', array['Gym floor access','Locker room','1 club location'], false),
('Unlimited 24/7', 79, 'mo', array['24/7 access, every club','Group classes included','Guest passes ×2/mo'], true),
('Premium + PT', 129, 'mo', array['Everything in Unlimited','4 PT sessions/mo','Priority booking'], false);

-- Streaks / check-ins / referrals / leaderboard / progress photos
-- (see add_growth_features.sql for the standalone migration; mirrored
-- here so a fresh install has these tables from the start).
create table if not exists public.member_stats (
  device_user_id text primary key,
  display_name text not null default 'Member',
  total_visits int not null default 0,
  current_streak int not null default 0,
  last_activity_date date,
  referral_code text unique,
  referred_by text,
  created_at timestamptz not null default now()
);

create table if not exists public.progress_photos (
  id uuid primary key default gen_random_uuid(),
  device_user_id text not null,
  image_url text not null,
  taken_at timestamptz not null default now()
);

alter table public.member_stats enable row level security;
alter table public.progress_photos enable row level security;

drop policy if exists "Public read" on public.member_stats;
create policy "Public read" on public.member_stats for select using (true);

drop policy if exists "Anon full access" on public.member_stats;
create policy "Anon full access" on public.member_stats for all using (true) with check (true);

drop policy if exists "Anon full access" on public.progress_photos;
create policy "Anon full access" on public.progress_photos for all using (true) with check (true);
