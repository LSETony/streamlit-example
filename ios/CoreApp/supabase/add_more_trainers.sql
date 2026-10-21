-- Adds 2 more trainer cards. Run once in the Supabase SQL Editor. Reuses
-- the 2 existing trainer photos (Trainer1/Trainer2 bundled assets) — no
-- new image assets needed, each trainer is still distinct by name/
-- specialty/tags/bio.
insert into public.trainers (image_name, name, specialty, rating, reviews, price_label, price_compact, next_available, availability_color, years_experience, clients, sessions, tags, bio) values
('Trainer1', 'Daniil Orlov', 'Personal trainer', '4.8', 134, '$40/h', '40', 'Mon', 'accent', '6 years', 35, 1320,
 array['HIIT','Fat loss','Functional training'],
 'Builds high-intensity, functional programs for members chasing fat loss and conditioning rather than pure strength numbers.'),
('Trainer2', 'Sofia Reyes', 'Personal trainer', '4.9', 189, '$48/h', '48', 'Wed', 'success', '8 years', 52, 1975,
 array['Powerlifting','Mobility','Injury prevention'],
 'Powerlifting-focused coaching with a strong emphasis on mobility work and injury prevention for lifters training around old injuries.');
