#!/usr/bin/env bash
# Установка core. на чистый сервер (Ubuntu 22.04/24.04) одной командой:
#
#   curl -fsSL https://raw.githubusercontent.com/<org>/<repo>/<branch>/deploy/install.sh | sudo bash -s -- --demo
#   или из клонированного репозитория:  sudo bash deploy/install.sh --demo
#
# Параметры:
#   --domain example.ru   свой домен: кабинет на app.example.ru, API на api.example.ru (A-записи → IP сервера).
#                         Без параметра используются бесплатные адреса app.<IP>.sslip.io и api.<IP>.sslip.io.
#   --demo                загрузить демо-зал «Атлет» (входы: owner@demo.core / demo12345)
#   --repo URL --branch B откуда брать код, если скрипт запущен не из репозитория
set -euo pipefail

DOMAIN="" DEMO=0
REPO="${CORE_REPO:-https://github.com/LSETony/streamlit-example.git}"
BRANCH="${CORE_BRANCH:-claude/pensive-hawking-361iv6}"
DIR="${CORE_DIR:-/opt/core}"
while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --demo) DEMO=1; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    *) echo "Неизвестный параметр: $1"; exit 1 ;;
  esac
done

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
[ "$(id -u)" = 0 ] || { echo "Запустите через sudo"; exit 1; }

log "Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
command -v git >/dev/null || (apt-get update -y && apt-get install -y git)

log "Код"
if [ -f "$(dirname "$0")/docker-compose.yml" ] && [ -d "$(dirname "$0")/../web" ]; then
  DIR="$(cd "$(dirname "$0")/.." && pwd)"
elif [ -d "$DIR/.git" ]; then
  git -C "$DIR" fetch origin "$BRANCH" && git -C "$DIR" checkout -q "$BRANCH" && git -C "$DIR" pull -q origin "$BRANCH"
else
  git clone -q --branch "$BRANCH" "$REPO" "$DIR"
fi
cd "$DIR/deploy"

IP="$(curl -fsS4 https://api.ipify.org || curl -fsS4 https://ifconfig.me)"
if [ -n "$DOMAIN" ]; then APP="app.$DOMAIN"; API="api.$DOMAIN"; else APP="app.${IP//./-}.sslip.io"; API="api.${IP//./-}.sslip.io"; fi

log "Секреты (.env)"
if [ ! -f .env ]; then
  docker run --rm -v "$PWD:/w" -w /w node:22-alpine node keys.mjs > .env
fi
setenv() { if grep -q "^$1=" .env; then sed -i "s|^$1=.*|$1=$2|" .env; else echo "$1=$2" >> .env; fi; }
setenv API_EXTERNAL_URL "https://$API"
setenv SITE_URL "https://$APP"
setenv PUBLIC_APP_URL "https://$APP"
setenv ADDITIONAL_REDIRECT_URLS "https://$APP/auth/callback,https://$APP/reset-password"
setenv APP_DOMAIN "$APP"
setenv API_DOMAIN "$API"
chmod 600 .env

log "Запуск (первая сборка кабинета занимает 3–5 минут)"
docker compose -f docker-compose.yml -f docker-compose.public.yml --env-file .env up -d --build

log "Миграции базы"
for i in $(seq 1 90); do
  docker compose -f docker-compose.yml --env-file .env logs migrate 2>/dev/null | grep -q "migrations: done" && break
  sleep 2
done

if [ "$DEMO" = 1 ]; then
  log "Демо-данные"
  if [ "$(docker exec core-db-1 psql -U supabase_admin -d postgres -tAc 'select count(*) from public.gyms')" = "0" ]; then
    docker exec -i core-db-1 psql -U supabase_admin -d postgres -q -o /dev/null < "$DIR/supabase/seed.sql"
  fi
fi

cat <<MSG

──────────────────────────────────────────────
 core. запущен

 Кабинет:  https://$APP
 API:      https://$API   (для iOS-приложения)
MSG
[ "$DEMO" = 1 ] && cat <<MSG

 Демо-входы (пароль demo12345):
   owner@demo.core      — владелец
   admin@demo.core      — администратор
   reception@demo.core  — ресепшен
   team@demo.core       — команда core.
MSG
cat <<MSG

 Секреты: $DIR/deploy/.env (храните копию в надёжном месте)
 Первый HTTPS-сертификат выпускается 10–60 секунд после старта.
──────────────────────────────────────────────
MSG
