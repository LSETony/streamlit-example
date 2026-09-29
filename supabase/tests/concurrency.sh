#!/usr/bin/env bash
# Приёмка 5.5: два клиента одновременно записываются на последнее место — проходит ровно один.
# Запуск: ./supabase/tests/concurrency.sh <database> (база с применёнными миграциями)
set -euo pipefail
DB=$1
PSQL="psql -X -q -t -A -v ON_ERROR_STOP=1 -d $DB"
$PSQL >/dev/null <<'SQL'
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000c0001', 'race-owner@test.ru') on conflict do nothing;
set request.jwt.claim.sub = '00000000-0000-0000-0000-0000000c0001';
set role authenticated;
select set_config('race.gym', public.create_gym('Гонка', 'Владелец')::text, false);
insert into public.clients (id, gym_id, full_name, phone) values
  ('00000000-0000-0000-0000-0000000c1001', current_setting('race.gym')::uuid, 'Первый', '+79160001001'),
  ('00000000-0000-0000-0000-0000000c1002', current_setting('race.gym')::uuid, 'Второй', '+79160001002');
select public.create_schedule_series(current_setting('race.gym')::uuid, 'Последнее место',
  ((now() + interval '1 day') at time zone 'Europe/Moscow')::timestamp, 60, 1);
reset role;
SQL
ITEM=$($PSQL -c "select id from public.schedule_items where title = 'Последнее место'")
book() {
  $PSQL -c "begin;
    set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000c0001';
    set local role authenticated;
    select public.book_class('$ITEM', '$1');
    select pg_sleep(1);
    commit;" >/dev/null 2>&1 && echo ok || echo fail
}
book 00000000-0000-0000-0000-0000000c1001 > /tmp/race1.$$ &
book 00000000-0000-0000-0000-0000000c1002 > /tmp/race2.$$ &
wait
R1=$(cat /tmp/race1.$$); R2=$(cat /tmp/race2.$$); rm -f /tmp/race1.$$ /tmp/race2.$$
BOOKED=$($PSQL -c "select count(*) from public.bookings where schedule_item_id = '$ITEM' and status = 'booked'")
echo "session1=$R1 session2=$R2 booked=$BOOKED"
if [ "$BOOKED" = "1" ] && [ "$R1" != "$R2" ]; then echo "concurrency: OK"; else echo "concurrency: FAILED"; exit 1; fi
