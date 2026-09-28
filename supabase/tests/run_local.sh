#!/usr/bin/env bash
# Прогон миграций и SQL-тестов на локальном PostgreSQL 15+ (без Docker и Supabase CLI).
# Использование: PGHOST=... PGUSER=postgres ./supabase/tests/run_local.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${TEST_DB:-core_test}
PSQL="psql -X -v ON_ERROR_STOP=1 -q"
dropdb --if-exists "$DB" >/dev/null 2>&1 || true
createdb "$DB"
$PSQL -d "$DB" -f tests/local/supabase_stub.sql
for f in migrations/*.sql; do
  echo "migrate: $f"
  $PSQL -d "$DB" -f "$f" -o /dev/null
done
fail=0
for t in tests/*.sql; do
  echo "test: $t"
  if ! $PSQL -d "$DB" -f "$t" -o /dev/null; then fail=1; echo "FAILED: $t"; fi
done
echo "test: tests/concurrency.sh"
./tests/concurrency.sh "$DB" || fail=1
if [ "${1:-}" != "--keep" ]; then dropdb "$DB"; fi
[ $fail -eq 0 ] && echo "ALL SQL TESTS PASSED"
exit $fail
