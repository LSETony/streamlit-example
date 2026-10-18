-- Роль «тренер». Новое значение перечисления должно появиться в отдельной транзакции, до политик, которые его используют.
alter type public.staff_role add value if not exists 'trainer';
