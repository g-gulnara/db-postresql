#!/bin/bash

set -uo pipefail

LOG_FILE="chaos/logs/scenario1_$(date +%Y%m%d_%H%M%S).log"
mkdir -p chaos/logs

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

DB_USER="${POSTGRES_USER:-library_user}"
DB_PASS="${POSTGRES_PASSWORD:-library_password}"
DB_NAME="${POSTGRES_DB:-library}"

PATRONI1=$(docker ps --format "{{.Names}}" | grep patroni1)
PATRONI2=$(docker ps --format "{{.Names}}" | grep patroni2)

log "Containers: PATRONI1=$PATRONI1  PATRONI2=$PATRONI2"

patroni_role() {
  local PORT=$1
  curl -s --max-time 3 "http://localhost:${PORT}/health" 2>/dev/null \
    | grep -o '"role": *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' \
    || echo "unreachable"
}

pg_check() {
  docker exec -e PGPASSWORD="$DB_PASS" "$PATRONI2" \
    psql -h haproxy -p 5000 -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT inet_server_addr(), pg_is_in_recovery();" -t 2>&1 \
    || echo "CONNECTION FAILED"
}

log "=== BEFORE FAILURE ==="
log "patroni1 role: $(patroni_role 8008)"
log "patroni2 role: $(patroni_role 8009)"
log "PostgreSQL via HAProxy: $(pg_check)"

log ""
log "=== INJECTING FAILURE: stopping $PATRONI1 ==="
FAIL_TIME=$(date +%s)
docker stop "$PATRONI1"
log "Stopped at $(date '+%H:%M:%S')"

log ""
log "=== MONITORING FAILOVER (60s) ==="

FAILOVER_DETECTED=false
FAILOVER_TIME=""

for i in $(seq 1 20); do
  sleep 3
  ELAPSED=$(( $(date +%s) - FAIL_TIME ))
  log "--- t+${ELAPSED}s ---"

  ROLE=$(patroni_role 8009)
  log "patroni2 role: $ROLE"

  CONN=$(pg_check)
  log "HAProxy→PG: $CONN"

  if [[ "$ROLE" == "primary" ]] && [[ "$FAILOVER_DETECTED" == "false" ]]; then
    FAILOVER_DETECTED=true
    FAILOVER_TIME=$ELAPSED
    log "*** FAILOVER DETECTED at t+${FAILOVER_TIME}s ***"
  fi
done

log ""
log "=== RECOVERY: starting $PATRONI1 ==="
docker start "$PATRONI1"
log "Waiting 30s for rejoin..."
sleep 30

log "patroni1 role: $(patroni_role 8008)"
log "patroni2 role: $(patroni_role 8009)"
log "PostgreSQL after recovery: $(pg_check)"

log ""
log "=== SUMMARY ==="
if [[ "$FAILOVER_DETECTED" == "true" ]]; then
  log "Failover SUCCEEDED in ${FAILOVER_TIME}s"
else
  log "Failover NOT detected within 60s"
fi
log "Log: $LOG_FILE"