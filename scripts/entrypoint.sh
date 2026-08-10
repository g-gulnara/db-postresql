#!/bin/bash
set -e

# Ожидание доступности базы данных
echo "Проверка доступности базы данных..."
until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER"; do
  echo "Ожидание postgres на $POSTGRES_HOST:$POSTGRES_PORT..."
  sleep 2
done

# Создание тестовой базы данных для Seqwall
export PGPASSWORD=$POSTGRES_PASSWORD
echo "Подготовка тестовой базы данных ${POSTGRES_DB}_test..."
psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS ${POSTGRES_DB}_test;"
psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE ${POSTGRES_DB}_test;"

# Запуск Seqwall Staircase
export TEST_PG_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/${POSTGRES_DB}_test?sslmode=disable"
export LIQUIBASE_URL="jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/${POSTGRES_TEST_DB}"
export LIQUIBASE_CLASSPATH="/liquibase/lib/postgresql-42.7.2.jar"

echo "Запуск тестирования Seqwall staircase..."
seqwall staircase \
  --postgres-url "$TEST_PG_URL" \
  --migrations-path "/migrations" \
  --upgrade "/scripts/ci-up-one.sh {current_migration}" \
  --downgrade "/scripts/ci-down-one.sh {current_migration}"

echo "Тестирование успешно завершено. Применение миграций к основной БД..."

cat <<EOF > /tmp/master.xml
<?xml version="1.0" encoding="UTF-8"?>
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog
    http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-latest.xsd">
EOF

FILES=$(ls /migrations/*.sql | sort)
for f in $FILES; do
  BASENAME=$(basename "$f")
  VERSION=$(echo "$BASENAME" | sed 's/^\([0-9]\+\)_.*/\1/')
  if [ -n "$MIGRATION_VERSION" ] && [ "$VERSION" -gt "$MIGRATION_VERSION" ]; then
    echo "Пропуск $BASENAME (версия $VERSION > $MIGRATION_VERSION)"
    continue
  fi
  echo "    <include file=\"/migrations/$BASENAME\" relativeToChangelogFile=\"false\"/>" >> /tmp/master.xml
done

echo "</databaseChangeLog>" >> /tmp/master.xml

export LIQUIBASE_URL="jdbc:postgresql://$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
liquibase --url="$LIQUIBASE_URL" \
    --changeLogFile=/tmp/master.xml \
    --username="$POSTGRES_USER" \
    --password="$POSTGRES_PASSWORD" \
    --searchPath="/" \
    --classpath="$LIQUIBASE_CLASSPATH" \
    update

echo "Запуск сидирования данных..."
python3 /seeds/seed.py
