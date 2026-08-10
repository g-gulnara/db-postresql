#!/bin/bash
set -e
echo "=== Starting Patroni: ${PATRONI_NAME} ==="

envsubst < /etc/patroni/patroni.yml > /tmp/patroni.yml

if [ "$(id -u)" = "0" ]; then
    chown -R postgres:postgres /var/lib/postgresql
    chmod 700 /var/lib/postgresql/data
    exec gosu postgres patroni /tmp/patroni.yml
else
    chmod 700 /var/lib/postgresql/data 2>/dev/null || true
    exec patroni /tmp/patroni.yml
fi