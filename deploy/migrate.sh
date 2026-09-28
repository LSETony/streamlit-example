#!/usr/bin/env bash
# Применяет новые миграции по порядку и ведёт учёт в supabase_migrations.schema_migrations
set -euo pipefail
until pg_isready -h "$PGHOST" -q; do sleep 1; done
# ждём, пока GoTrue создаст свои таблицы
for i in $(seq 1 60); do
  psql -tAc "select 1 from information_schema.tables where table_schema='auth' and table_name='identities'" | grep -q 1 && break
  sleep 1
done
psql -v ON_ERROR_STOP=1 -q <<'SQL'
create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (version text primary key, name text, applied_at timestamptz default now());
SQL
for f in /migrations/*.sql; do
  name=$(basename "$f" .sql)
  version=${name%%_*}
  if psql -tAc "select 1 from supabase_migrations.schema_migrations where version = '$version'" | grep -q 1; then continue; fi
  echo "apply $name"
  psql -v ON_ERROR_STOP=1 -q --single-transaction -f "$f"
  psql -q -c "insert into supabase_migrations.schema_migrations (version, name) values ('$version', '$name')"
done
# Воркер уведомлений каждую минуту (pg_cron + pg_net → Edge Function notify)
if [ -n "${CRON_SECRET:-}" ]; then
  psql -v ON_ERROR_STOP=1 -q -v secret="$CRON_SECRET" <<'SQL'
create extension if not exists pg_net;
select cron.unschedule(jobid) from cron.job where jobname = 'core-notify';
select cron.schedule('core-notify', '* * * * *',
  format($$select net.http_post(url := 'http://kong:8000/functions/v1/notify', headers := jsonb_build_object('x-cron-secret', %L, 'Content-Type', 'application/json'), body := '{}'::jsonb)$$, :'secret'));
SQL
fi
echo "migrations: done"
