#!/usr/bin/env bash
# Резервная копия базы self-hosted core.: pg_dump из контейнера db → backups/core-YYYYmmdd-HHMM.sql.gz.
# Хранит последние KEEP_DAYS дней (по умолчанию 14). Если задан BACKUP_S3_URI (например s3://bucket/core)
# и установлен aws CLI, копия отправляется ещё и в объектное хранилище — держите её вне сервера.
#
# Запуск каждую ночь (crontab -e):  15 3 * * * /opt/core/deploy/backup.sh >> /var/log/core-backup.log 2>&1
# Восстановление:  gunzip -c backups/core-….sql.gz | docker compose -f deploy/docker-compose.yml exec -T db psql -U postgres -d postgres
set -euo pipefail
cd "$(dirname "$0")"
KEEP_DAYS=${KEEP_DAYS:-14}
DIR=${BACKUP_DIR:-./backups}
mkdir -p "$DIR"
file="$DIR/core-$(date +%Y%m%d-%H%M).sql.gz"
docker compose -f docker-compose.yml exec -T db pg_dump -U postgres -d postgres --clean --if-exists \
  --exclude-schema=_realtime --exclude-schema=realtime | gzip -9 > "$file.tmp"
mv "$file.tmp" "$file"
echo "$(date -Is) backup $file ($(du -h "$file" | cut -f1))"
if [ -n "${BACKUP_S3_URI:-}" ] && command -v aws >/dev/null; then
  aws s3 cp "$file" "$BACKUP_S3_URI/$(basename "$file")" --only-show-errors
  echo "$(date -Is) uploaded to $BACKUP_S3_URI"
fi
find "$DIR" -name 'core-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
