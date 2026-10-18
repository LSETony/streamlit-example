# Эксплуатация: домен, почта, SMS, оплаты, мониторинг, бэкапы

Чек-лист перед запуском с реальными залами. Для демо достаточно `docs/vercel.md`.

## 1. Свой домен

**Vercel (кабинет):** Project → Settings → Domains → добавьте, например, `app.<ваш-домен>`. У регистратора
создайте запись `CNAME app → cname.vercel-dns.com` (Vercel покажет точное значение). Сертификат выпустится сам.

После смены адреса обновите:

* переменную `PUBLIC_APP_URL=https://app.<ваш-домен>` в Vercel (ссылки в приглашениях, оплатах, подписке);
* Supabase → Authentication → URL Configuration: **Site URL** и **Redirect URLs** (`https://app.<ваш-домен>/auth/callback`);
* адреса уведомлений в Stripe и ЮKassa (раздел 4);
* ссылку `APP_URL` в лендинге (`landing/index.html`, репозиторий `core-landing`).

**Self-hosted (Россия):** домен указывается в `deploy/Caddyfile`, сертификат Let's Encrypt Caddy получает сам (`docs/deploy.md`).

## 2. Почта (приглашения сотрудников, сброс пароля)

Встроенная почта Supabase ограничена несколькими письмами в час и подходит только для проверки. Подключите свой SMTP:

* Supabase Cloud: Authentication → Emails → **SMTP Settings** — хост, порт 587, логин, пароль, отправитель
  `core. <no-reply@<ваш-домен>>`.
* Self-hosted: переменные `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_ADMIN_EMAIL`, `SMTP_SENDER_NAME` в `deploy/.env`.

Подходят Resend, Postmark, Amazon SES, для России — Unisender Go. У регистратора домена добавьте записи SPF и DKIM,
которые выдаст сервис, и DMARC (`v=DMARC1; p=quarantine`), иначе письма уйдут в спам.

## 3. SMS-коды для приложения клиента (`/m`)

Клиенты входят по номеру телефона. Supabase Cloud: Authentication → Sign In / Providers → **Phone** → включите и
выберите провайдера (Twilio, MessageBird, Vonage). Для номеров ОАЭ нужен зарегистрированный отправитель (Sender ID) у
провайдера. Self-hosted использует SMS.ru через `supabase/functions/sms-hook` (`SMSRU_API_ID`, см. `deploy/keys.mjs`).

Для проверки без SMS: Phone → **Test OTPs**, например `971500000001=123456`.

## 4. Онлайн-оплата

**Залы в России — ЮKassa:** ключи вводит владелец в настройках зала; адрес уведомлений
`https://<адрес API>/functions/v1/payments/webhook` (нужны Edge Functions, `docs/vercel.md`).

**Залы в ОАЭ — Stripe зала:** владелец вводит секретный ключ в «Настройки → Онлайн-оплата Stripe», в Stripe создаёт
адрес уведомлений `https://app.<ваш-домен>/api/stripe/gym/<id зала>` (готовый адрес показан в настройках) с событиями
`checkout.session.completed`, `checkout.session.expired`, `checkout.session.async_payment_succeeded`,
`checkout.session.async_payment_failed` и вставляет секрет подписи `whsec_…`. Нужна переменная `GYM_SECRETS_KEY`.

**Подписка core. (залы в ОАЭ) — Stripe-аккаунт core.:**

1. В Stripe создайте продукт «core.» и ежемесячные цены в AED для тарифов «Старт», «Бизнес», «Сеть».
2. Developers → Webhooks → адрес `https://app.<ваш-домен>/api/stripe/billing`, события `checkout.session.completed`,
   `invoice.paid`, `customer.subscription.deleted`.
3. Settings → Billing → Customer portal: включите портал (смена карты, отмена).
4. Переменные Vercel: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_START`, `STRIPE_PRICE_BUSINESS`,
   `STRIPE_PRICE_NETWORK`.

После этого у владельца зала из ОАЭ в настройках появится кнопка «Оплатить картой»; каждая оплата продлевает
«Оплачено до» на период подписки плюс 3 дня. Российские залы оплачивают по счёту, дату ставит команда в `/admin`.

## 5. Мониторинг ошибок

Серверные ошибки кабинета отправляются из `web/instrumentation.ts`, если задана хотя бы одна из переменных:

* `SENTRY_DSN` — DSN проекта Sentry (Settings → Client Keys);
* `TELEGRAM_ALERT_BOT_TOKEN` и `TELEGRAM_ALERT_CHAT_ID` — сообщение в чат команды (те же переменные используют Edge Functions).

Передаются только путь без параметров, метод и текст ошибки — без персональных данных клиентов.
Доступность сайта удобно проверять внешним сервисом (UptimeRobot, Better Stack) по адресу `/login`.

## 6. Резервные копии

* **Supabase Cloud:** ежедневные бэкапы есть на тарифе Pro (Database → Backups), восстановление на точку во
  времени — дополнение PITR. На бесплатном тарифе бэкапов нет: делайте выгрузку вручную
  (`pg_dump "<connection string>" | gzip > core.sql.gz`) или перейдите на Pro до подключения реальных залов.
* **Self-hosted:** `deploy/backup.sh` — `pg_dump` в `deploy/backups/`, хранение 14 дней, при заданном
  `BACKUP_S3_URI` копия уходит в объектное хранилище (Yandex Object Storage, Selectel S3). Ночной запуск:
  `15 3 * * * /opt/core/deploy/backup.sh >> /var/log/core-backup.log 2>&1`. Раз в месяц проверяйте восстановление
  на отдельном сервере — команда в начале скрипта.

## 7. Переменные окружения кабинета (Vercel)

| Переменная | Обязательна | Зачем |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` | да | подключение к Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | да | приглашения, демо, удаление аккаунта клиента, уведомления оплат |
| `PUBLIC_APP_URL` | да для своего домена | адрес кабинета в ссылках |
| `GYM_SECRETS_KEY` | для оплат и WhatsApp | шифрование ключей залов (32 байта в base64) |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_*` | для подписки core. | оплата подписки картой |
| `SENTRY_DSN`, `TELEGRAM_ALERT_*` | нет | мониторинг ошибок |
