# Развёртывание core. на серверах в России

Персональные данные клиентов хранятся в РФ (152-ФЗ), поэтому Supabase разворачивается self-hosted на Yandex Cloud
или Selectel. Шаблон — `deploy/docker-compose.yml`. Он проверен на стенде: PostgreSQL, Auth, REST, Realtime,
Edge Functions, шлюз Kong, миграции и расписание фоновых заданий.

## Окружения

| Окружение | Назначение | Данные |
|---|---|---|
| dev | разработка, `docker compose` на ноутбуке | `supabase/seed.sql` (демо-зал «Атлет») |
| staging | пилотные залы до запуска, приёмка | тестовые данные |
| production | работающие залы | реальные данные, резервные копии |

Схема базы меняется только миграциями из `supabase/migrations` (сервис `migrate` применяет новые по порядку).

## Сервер

* ВМ: 4 vCPU / 8 ГБ / SSD 100 ГБ (хватает на 100 залов и 50 000 клиентов), Ubuntu 24.04, Docker.
* Отдельный диск или managed-снапшоты для тома `db-data`.
* Nginx или балансировщик облака перед Kong: только HTTPS (TLS 1.2+), сертификат Let's Encrypt.
  Домены, например: `api.core.example.ru` → Kong :54321, `app.core.example.ru` → кабинет (Next.js).
* Наружу открыты только 443/80. Порт PostgreSQL слушает только 127.0.0.1.

## Самый быстрый путь

`deploy/install.sh` ставит Docker, скачивает код, генерирует секреты, собирает кабинет, поднимает всё за Caddy
с автоматическим HTTPS и (с `--demo`) загружает демо-зал:

```bash
sudo bash deploy/install.sh --demo                    # адреса app.<IP>.sslip.io и api.<IP>.sslip.io
sudo bash deploy/install.sh --domain core.example.ru  # app.core.example.ru и api.core.example.ru
```

Повторный запуск обновляет код и пересобирает кабинет, секреты в `deploy/.env` сохраняются.

## Первый запуск вручную

```bash
git clone … && cd …
node deploy/keys.mjs > deploy/.env        # секреты: JWT, anon/service ключи, пароли, ключ шифрования ЮKassa
# отредактировать deploy/.env: API_EXTERNAL_URL, SITE_URL, SMTP, SMSRU_API_ID, APNS_*, TELEGRAM_ALERT_*
docker compose -f deploy/docker-compose.yml --env-file deploy/.env up -d
docker compose -f deploy/docker-compose.yml --env-file deploy/.env logs migrate   # «migrations: done»
```

Команда core. (суперадмин) — добавить пользователя в `platform_admins`:

```sql
insert into public.platform_admins (user_id) select id from auth.users where email = 'team@core.ru';
```

## Кабинет (Next.js)

```bash
cd web && npm ci && npm run build
NEXT_PUBLIC_SUPABASE_URL=https://api.core.example.ru \
NEXT_PUBLIC_SUPABASE_ANON_KEY=… SUPABASE_SERVICE_ROLE_KEY=… GYM_SECRETS_KEY=… \
PUBLIC_APP_URL=https://app.core.example.ru npm start
```

`SUPABASE_SERVICE_ROLE_KEY` и `GYM_SECRETS_KEY` — только в окружении сервера, в браузер не попадают
(модули с ними помечены `server-only`). `GYM_SECRETS_KEY` должен совпадать у кабинета и Edge Functions.

## Интеграции

| Что | Настройка |
|---|---|
| ЮKassa | Каждый зал вводит shopId и секретный ключ в «Настройки зала» (ключ шифруется AES-256-GCM). В ЛК ЮKassa зала — HTTP-уведомления на `https://api…/functions/v1/payments/webhook`, события `payment.succeeded`, `payment.canceled`, `refund.succeeded`. |
| SMS-коды входа | `SMS_HOOK_ENABLED=true`, `SMS_HOOK_URI=https://api…/functions/v1/sms-hook`, `SMSRU_API_ID` — коды уходят через SMS.ru (Send SMS Hook Auth). |
| Push | `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY` (.p8), `APNS_BUNDLE_ID`, `APNS_PRODUCTION=true`. |
| SMS/email клиентам без приложения | `SMSRU_API_ID`, `UNISENDER_GO_API_KEY`, `EMAIL_FROM`; канал выбирает зал в настройках. |
| Письма сотрудникам | SMTP в `deploy/.env` (приглашения, восстановление пароля). |
| Оповещения команде | `TELEGRAM_ALERT_BOT_TOKEN`, `TELEGRAM_ALERT_CHAT_ID` — сбои оплат, возвратов, воркеров. |

## Фоновые задания (pg_cron)

Ставятся миграциями автоматически:

* `core-maintenance-15m` и `core-maintenance-nightly` — `run_maintenance()`: истёкшие абонементы → `expired`,
  статусы заморозок, автовыход из зала, отмена брошенных онлайн-оплат, напоминания об окончании абонемента.
* `core-notify` (каждую минуту) — вызывает Edge Function `notify`, которая отправляет очередь уведомлений.

## Резервные копии и восстановление (раздел 7: RPO ≤ 24 ч)

```bash
# /etc/cron.d/core-backup — каждый день в 03:30 МСК, хранение 14 дней, копия в Object Storage в РФ
30 3 * * * root docker exec core-db-1 pg_dump -U supabase_admin -Fc postgres > /backup/core-$(date +\%F).dump \
  && find /backup -name 'core-*.dump' -mtime +14 -delete \
  && s3cmd sync /backup/ s3://core-backups/ --delete-removed
```

Раз в месяц — проверка восстановления на staging:

```bash
docker exec -i core-db-1 pg_restore -U supabase_admin -d postgres --clean --if-exists < core-YYYY-MM-DD.dump
```

и прогон `web/e2e/smoke.mjs` на восстановленной базе.

## Обновления

Ночью по Москве: `git pull`, `docker compose … up -d` (сервис `migrate` применит новые миграции),
пересборка кабинета. Старая версия API Edge Functions работает минимум 3 месяца после выхода новой.

## Наблюдаемость

* Edge Functions пишут JSON-лог каждого запроса (путь, статус, время, код ошибки) — `docker logs core-functions-1`.
* Сбои оплат и воркеров — сообщение команде в Telegram.
* Рекомендуется: Uptime-мониторинг `https://api…/auth/v1/health` и кабинета, алерт в тот же Telegram-чат.
