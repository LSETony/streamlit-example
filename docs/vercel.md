# Демо на Vercel + Supabase Cloud

Самый быстрый способ получить ссылку: кабинет на Vercel, база и вход — в облачном Supabase. Обе платформы
бесплатны для демо.

> Облачный Supabase хранит данные за пределами РФ. Для показа на демо-данных это допустимо; для реальных
> клиентов зала используйте self-hosted вариант (`docs/deploy.md`, 152-ФЗ).

## 1. Supabase (база и вход) — ~5 минут

1. Зарегистрируйтесь на supabase.com и создайте проект (регион — Frankfurt или ближайший, пароль базы сохраните).
2. Откройте **SQL Editor → New query**, вставьте целиком содержимое файла `supabase/setup-cloud.sql`
   из репозитория и нажмите **Run**. Файл создаёт все таблицы, права, функции и демо-зал «Атлет».
3. **Authentication → URL Configuration**: в Site URL впишите адрес кабинета на Vercel (появится на шаге 2,
   можно вернуться позже), в Redirect URLs добавьте `https://<адрес-кабинета>/auth/callback`.
4. **Project Settings → API**: скопируйте Project URL, anon (publishable) key и service_role (secret) key.

Ошибка `type "staff_role" already exists` значит, что файл уже выполнялся и база создана. Проверьте:
`select count(*) from clients;` — если 320, всё готово. Если нужно начать заново, выполните
`supabase/reset-cloud.sql` (удаляет всё core. в проекте), затем снова `supabase/setup-cloud.sql`.

### Обновление уже созданной базы

Если база создана раньше, новые миграции из `supabase/migrations` выполняются по одной в **SQL Editor**, по порядку.
Регионы Россия/ОАЭ (валюта, телефоны +971, выбор региона при регистрации) —
файл `supabase/migrations/20261005000001_regions.sql`. Без него российские залы работают как раньше,
но зал в ОАЭ создать нельзя.

## 2. Vercel (кабинет) — ~5 минут

1. На vercel.com: **Add New → Project → Import** репозитория `LSETony/streamlit-example`.
2. **Root Directory**: `web`. Framework определится сам (Next.js).
3. **Environment Variables**:

   | Переменная | Значение |
   |---|---|
   | `NEXT_PUBLIC_SUPABASE_URL` | Project URL из Supabase |
   | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | anon / publishable key |
   | `SUPABASE_SERVICE_ROLE_KEY` | service_role / secret key (только на сервере) |
   | `GYM_SECRETS_KEY` | необязательно: нужен для сохранения ключей ЮKassa; 32 случайных байта в base64 |

4. **Deploy**. Пока код в ветке `claude/pensive-hawking-361iv6`, а не в `main`: в **Settings → Git → Production Branch**
   укажите эту ветку (или слейте её в `main`) и нажмите **Redeploy** — тогда ссылка `https://<проект>.vercel.app`
   откроется без входа в Vercel.

## 3. Вход

Пароль у всех — `demo12345`: `owner@demo.core` (владелец), `admin@demo.core`, `reception@demo.core`,
`team@demo.core` (команда core.).

## Что не работает в таком демо

* Edge Functions (ссылка на онлайн-оплату, онлайн-возврат, API для iOS-приложения, отправка push/SMS) нужно
  отдельно выкладывать через Supabase CLI: `supabase functions deploy --project-ref <ref>` и задать секреты
  (`supabase secrets set GYM_SECRETS_KEY=… CRON_SECRET=…`). Всё остальное в кабинете работает без них.
* Вход клиентов по SMS требует подключить SMS-провайдера в Supabase Auth.
