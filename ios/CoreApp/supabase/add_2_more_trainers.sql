-- 2 more trainers with their own dedicated photos (Trainer3/Trainer4
-- assets, already added to the Xcode project). Run once in the Supabase
-- SQL Editor.
insert into public.trainers (image_name, name, specialty, rating, reviews, price_label, price_compact, next_available, availability_color, years_experience, clients, sessions, tags, bio) values
('Trainer3', 'Marco Fedele', 'Personal trainer', '4.9', 156, '$50/h', '50', 'Thu', 'success', '10 years', 44, 1680,
 array['Strength','Powerlifting','Hypertrophy'],
 'Strength-focused coaching built around progressive overload — works with members chasing real numbers on the big lifts.'),
('Trainer4', 'Elena Marchetti', 'Personal trainer', '4.8', 121, '$46/h', '46', 'Fri', 'accent', '7 years', 39, 1450,
 array['Conditioning','HIIT','Core strength'],
 'High-energy conditioning sessions built around circuits and core work — popular with members training for endurance events.');
