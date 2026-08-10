#!/bin/bash

set -uo pipefail

LOG_FILE="chaos/logs/scenario2_$(date +%Y%m%d_%H%M%S).log"
mkdir -p chaos/logs

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

DB_USER="${POSTGRES_USER:-library_user}"
DB_PASS="${POSTGRES_PASSWORD:-library_password}"
DB_NAME="${POSTGRES_DB:-library}"

ETCD=$(docker ps --format "{{.Names}}" | grep etcd | head -1)
PATRONI1=$(docker ps --format "{{.Names}}" | grep patroni1)
PATRONI2=$(docker ps --format "{{.Names}}" | grep patroni2)

log "Containers: ETCD=$ETCD  PATRONI1=$PATRONI1  PATRONI2=$PATRONI2"

patroni_health() {
  curl -s --max-time 3 "http://localhost:${1}/health" 2>/dev/null || echo '{"state":"unreachable"}'
}

dcs_last_seen() {
  curl -s --max-time 3 "http://localhost:${1}/patroni" 2>/dev/null \
    | grep -o '"dcs_last_seen":[0-9]*' | cut -d: -f2 || echo "N/A"
}

pg_check() {
  docker exec -e PGPASSWORD="$DB_PASS" "$PATRONI2" \
    psql -h haproxy -p 5000 -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT 'ok', pg_is_in_recovery();" -t 2>&1 \
    || echo "CONNECTION FAILED"
}

log "=== BEFORE FAILURE ==="
log "etcd health: $(docker exec "$ETCD" etcdctl endpoint health 2>&1)"
log "patroni1: $(patroni_health 8008)"
log "patroni2: $(patroni_health 8009)"
log "patroni1 dcs_last_seen: $(dcs_last_seen 8008)"
log "patroni2 dcs_last_seen: $(dcs_last_seen 8009)"
log "PostgreSQL: $(pg_check)"

log ""
log "=== INJECTING FAILURE: stopping etcd ==="
FAIL_TIME=$(date +%s)
docker stop "$ETCD"
log "etcd stopped at $(date '+%H:%M:%S')"

log ""
log "=== MONITORING without DCS (60s) ==="

for i in $(seq 1 20); do
  sleep 3
  ELAPSED=$(( $(date +%s) - FAIL_TIME ))
  log "--- t+${ELAPSED}s ---"
  log "patroni1: $(patroni_health 8008)"
  log "patroni2: $(patroni_health 8009)"
  log "patroni1 dcs_last_seen: $(dcs_last_seen 8008)"
  log "patroni2 dcs_last_seen: $(dcs_last_seen 8009)"
  log "HAProxy→PG: $(pg_check)"

  if [[ $i -eq 7 ]]; then
    log ">>> Attempting manual failover WITHOUT DCS..."
    RESULT=$(curl -s -X POST http://localhost:8008/failover \
      -H "Content-Type: application/json" \
      -d '{"master":"patroni1"}' 2>&1 || echo "request failed")
    log "Failover result: $RESULT"
  fi
done

log ""
log "=== RECOVERY: starting etcd ==="
docker start "$ETCD"
log "Waiting 30s for Patroni to reconnect..."
sleep 30

log "etcd health: $(docker exec "$ETCD" etcdctl endpoint health 2>&1)"
log "patroni1: $(patroni_health 8008)"
log "patroni2: $(patroni_health 8009)"
log "patroni1 dcs_last_seen after recovery: $(dcs_last_seen 8008)"
log "PostgreSQL after recovery: $(pg_check)"

log ""
log "=== SUMMARY ==="
log "etcd was isolated for ~60s"
log "Log: $LOG_FILE"