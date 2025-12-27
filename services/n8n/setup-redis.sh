#!/usr/bin/env bash
# Helper script to set up Redis ACL user for n8n
# Run this on the Redis container or from host with redis-cli access
# Usage: REDIS_ADMIN_PASS='your_admin_pass' bash services/n8n/setup-redis.sh

set -euo pipefail

REDIS_HOST="${QUEUE_BULL_REDIS_HOST:-redis.homelab.local}"
REDIS_PORT="${QUEUE_BULL_REDIS_PORT:-6379}"
REDIS_ADMIN_PASS="${REDIS_ADMIN_PASS:-CHANGEME}"
REDIS_USER="${QUEUE_BULL_REDIS_USERNAME:-n8n}"
REDIS_PASSWORD="${QUEUE_BULL_REDIS_PASSWORD:-CHANGEME}"

echo "[*] Creating Redis ACL user for n8n..."

if command -v redis-cli &> /dev/null; then
  # Running on Redis container
  redis-cli -a "${REDIS_ADMIN_PASS}" ACL SETUSER "${REDIS_USER}" on >"${REDIS_PASSWORD}" ~n8n:* +@all -@dangerous -@admin
  echo "[*] Testing connection..."
  redis-cli --user "${REDIS_USER}" -a "${REDIS_PASSWORD}" PING
else
  # Running from host or other location
  echo "[*] Using redis-cli from host..."
  redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" -a "${REDIS_ADMIN_PASS}" \
    ACL SETUSER "${REDIS_USER}" on >"${REDIS_PASSWORD}" ~n8n:* +@all -@dangerous -@admin
  echo "[*] Testing connection..."
  redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" --user "${REDIS_USER}" -a "${REDIS_PASSWORD}" PING
fi

echo "[✓] Redis ACL user created for n8n"

