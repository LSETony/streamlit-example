// Генерация секретов для self-hosted Supabase: JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY, пароли.
// Использование: node deploy/keys.mjs > deploy/.env  (затем отредактируйте адреса и SMTP/SMS)
import { createHmac, randomBytes } from "node:crypto";

const b64url = (buf) => Buffer.from(buf).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
const secret = process.env.JWT_SECRET ?? randomBytes(32).toString("hex");
const sign = (payload) => {
  const head = b64url(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const body = b64url(JSON.stringify(payload));
  const sig = b64url(createHmac("sha256", secret).update(`${head}.${body}`).digest());
  return `${head}.${body}.${sig}`;
};
const iat = Math.floor(Date.now() / 1000);
const exp = iat + 10 * 365 * 24 * 3600;

console.log(`POSTGRES_PASSWORD=${randomBytes(18).toString("hex")}
JWT_SECRET=${secret}
ANON_KEY=${sign({ role: "anon", iss: "supabase", iat, exp })}
SERVICE_ROLE_KEY=${sign({ role: "service_role", iss: "supabase", iat, exp })}
GYM_SECRETS_KEY=${randomBytes(32).toString("base64")}
CRON_SECRET=${randomBytes(24).toString("hex")}
SECRET_KEY_BASE=${randomBytes(48).toString("hex")}
SEND_SMS_HOOK_SECRET=v1,whsec_${randomBytes(32).toString("base64")}
# true — коды входа уходят через SMS.ru (нужен SMSRU_API_ID); false — тестовые коды SMS_TEST_OTP
SMS_HOOK_ENABLED=false
SMS_HOOK_URI=
# Публичные адреса
API_EXTERNAL_URL=http://localhost:54321
SITE_URL=http://localhost:3000
ADDITIONAL_REDIRECT_URLS=http://localhost:3000/auth/callback,http://localhost:3000/reset-password
KONG_HTTP_PORT=54321
POSTGRES_PORT=54322
JWT_EXPIRY=3600
# Почта для писем сотрудникам (приглашения, восстановление пароля)
ENABLE_EMAIL_AUTOCONFIRM=true
SMTP_ADMIN_EMAIL=noreply@core.local
SMTP_HOST=mail
SMTP_PORT=2500
SMTP_USER=
SMTP_PASS=
SMTP_SENDER_NAME=core.
# Вход клиентов приложения по SMS (российский шлюз подключается через Send SMS Hook или Twilio-совместимый провайдер)
ENABLE_PHONE_SIGNUP=true
ENABLE_PHONE_AUTOCONFIRM=false
SMS_TEST_OTP=79160000001:123456
# Интеграции (Edge Functions)
PUBLIC_APP_URL=http://localhost:3000
TELEGRAM_ALERT_BOT_TOKEN=
TELEGRAM_ALERT_CHAT_ID=
APNS_KEY_ID=
APNS_TEAM_ID=
APNS_PRIVATE_KEY=
APNS_BUNDLE_ID=
APNS_PRODUCTION=false
SMSRU_API_ID=
SMSRU_FROM=
UNISENDER_GO_API_KEY=
EMAIL_FROM=`);
