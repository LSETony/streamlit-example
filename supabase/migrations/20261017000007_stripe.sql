-- Stripe: онлайн-оплата абонементов для залов в ОАЭ (ключи зала) и подписка core. для залов (аккаунт core.)

-- Ключи Stripe зала: секретный ключ и секрет подписи уведомлений, оба зашифрованы
alter table public.gym_secrets
  add column stripe_secret_encrypted text,
  add column stripe_webhook_secret_encrypted text;

-- Подписка core.: покупатель и подписка в Stripe. Пишет только сервер (service role) по уведомлениям Stripe
alter table public.gyms
  add column stripe_customer_id text,
  add column stripe_subscription_id text;
create index gyms_stripe_customer_idx on public.gyms(stripe_customer_id) where stripe_customer_id is not null;
