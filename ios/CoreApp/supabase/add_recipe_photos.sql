-- Adds image_url to food_recipes and backfills real stock photos for the
-- 4 seeded recipes, replacing the gradient PhotoPlaceholder stand-ins. Run
-- once in the Supabase SQL Editor — safe to re-run.
alter table public.food_recipes add column if not exists image_url text;

update public.food_recipes set image_url = 'https://images.pexels.com/photos/1162255/pexels-photo-1162255.jpeg?auto=compress&cs=tinysrgb&w=1200' where name = 'Chicken Cajun';
update public.food_recipes set image_url = 'https://images.pexels.com/photos/6072378/pexels-photo-6072378.jpeg?auto=compress&cs=tinysrgb&w=1200' where name = 'Protein pancakes';
update public.food_recipes set image_url = 'https://images.pexels.com/photos/5892851/pexels-photo-5892851.jpeg?auto=compress&cs=tinysrgb&w=1200' where name = 'Beef Jerky';
update public.food_recipes set image_url = 'https://images.pexels.com/photos/3559899/pexels-photo-3559899.jpeg?auto=compress&cs=tinysrgb&w=1200' where name = 'Carnivore Soup';
