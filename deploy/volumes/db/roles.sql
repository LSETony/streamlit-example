-- Пароли служебных ролей Supabase (роли, которых нет в данной версии образа, пропускаются)
\set pgpass `echo "$POSTGRES_PASSWORD"`
select set_config('core.pgpass', :'pgpass', false);
do $$
declare r text;
begin
  foreach r in array array['authenticator', 'pgbouncer', 'supabase_auth_admin', 'supabase_functions_admin', 'supabase_storage_admin'] loop
    if exists (select 1 from pg_roles where rolname = r) then
      execute format('alter user %I with password %L', r, current_setting('core.pgpass'));
    end if;
  end loop;
end $$;
