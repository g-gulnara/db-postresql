#!/bin/sh
set -e

echo "[$(date)] Инициализация backup-агента..."

until mc alias set minio \
  "http://${MINIO_HOST}:${MINIO_PORT}" \
  "$MINIO_ROOT_USER" \
  "$MINIO_ROOT_PASSWORD" 2>/dev/null; do
  echo "[$(date)] Ожидание MinIO на ${MINIO_HOST}:${MINIO_PORT}..."
  sleep 3
done
echo "[$(date)] MinIO доступен"

if ! mc ls "minio/${BUCKET_BACKUP_NAME}" > /dev/null 2>&1; then
  mc mb "minio/${BUCKET_BACKUP_NAME}"
  echo "[$(date)] Бакет ${BUCKET_BACKUP_NAME} создан"
else
  echo "[$(date)] Бакет ${BUCKET_BACKUP_NAME} уже существует"
fi

mc anonymous set none "minio/${BUCKET_BACKUP_NAME}"
echo "[$(date)] Политика доступа: private (только через credentials)"

mkdir -p /metrics
cat > /metrics/backup_metrics.prom <<EOF
# HELP backup_last_timestamp Unix timestamp последнего успешного бэкапа
# TYPE backup_last_timestamp gauge
backup_last_timestamp 0

# HELP backup_last_size_bytes Размер последнего бэкапа в байтах
# TYPE backup_last_size_bytes gauge
backup_last_size_bytes 0
EOF

echo "[$(date)] Первый бэкап при старте..."
/scripts/backup.sh

echo "[$(date)] Настройка cron: ${BACKUP_INTERVAL}"
echo "${BACKUP_INTERVAL} /scripts/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

python3 /scripts/metrics_exporter.py &

echo "[$(date)] Запуск планировщика..."
crond -f -l 2