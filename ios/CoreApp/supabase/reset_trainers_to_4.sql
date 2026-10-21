-- Resets Trainers down to exactly 4 cards, one per unique photo
-- (Trainer1..Trainer4 assets) — no more reusing the same photo for 2
-- different trainers. Safe to re-run.
delete from public.trainers;

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
