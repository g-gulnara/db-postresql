#!/bin/sh
set -e

BUCKET="${BUCKET_BACKUP_NAME:-backups}"
RETENTION="${BACKUP_RETENTION_COUNT:-5}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="backup_${TIMESTAMP}.sql.gz"
METRICS_FILE="/metrics/backup_metrics.prom"

echo "[$(date)] Запуск бэкапа: $BACKUP_FILE"

PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  -h "$POSTGRES_HOST" \
  -p "$POSTGRES_PORT" \
  -U "$POSTGRES_USER" \
  "$POSTGRES_DB" \
  | gzip \
  | mc pipe "minio/${BUCKET}/${BACKUP_FILE}"

echo "[$(date)] Бэкап загружен в MinIO: ${BUCKET}/${BACKUP_FILE}"

BACKUP_SIZE=$(mc stat "minio/${BUCKET}/${BACKUP_FILE}" | grep Size | awk '{print $3}')
BACKUP_TIMESTAMP=$(date +%s)

echo "[$(date)] Применяем ретеншн: оставляем последние $RETENTION бэкапов"
mc ls "minio/${BUCKET}/" \
  | grep "backup_" \
  | awk '{print $NF}' \
  | sort \
  | head -n "-${RETENTION}" \
  | while read -r old_file; do
      echo "[$(date)] Удаляем старый бэкап: $old_file"
      mc rm "minio/${BUCKET}/${old_file}"
    done

mkdir -p /metrics
cat > "$METRICS_FILE" <<EOF
# HELP backup_last_timestamp Unix timestamp последнего успешного бэкапа
# TYPE backup_last_timestamp gauge
backup_last_timestamp $BACKUP_TIMESTAMP

# HELP backup_last_size_bytes Размер последнего бэкапа в байтах
# TYPE backup_last_size_bytes gauge
backup_last_size_bytes ${BACKUP_SIZE:-0}
EOF

echo "[$(date)] Бэкап завершён успешно"