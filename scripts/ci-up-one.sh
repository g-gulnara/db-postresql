#!/bin/bash
set -e

MIGRATION_FILE="$1"

if [ -z "$MIGRATION_FILE" ]; then
  echo "Не указан файл миграции!"
  exit 1
fi

echo "=== ci-up-one.sh вызван c: $MIGRATION_FILE ==="

DB_URL="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_TEST_DB}"
echo "=== DB_URL: $DB_URL ==="

liquibase --url="$DB_URL" \
  --changeLogFile="$MIGRATION_FILE" \
  --username="$POSTGRES_USER" \
  --password="$POSTGRES_PASSWORD" \
  --driver=org.postgresql.Driver \
  --searchPath="/,/migrations" \
  --classpath=${LIQUIBASE_CLASSPATH:-"/liquibase/lib/postgresql-42.7.2.jar"} \
  update
