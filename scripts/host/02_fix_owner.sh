#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-}"
SERVICE="${2:-}"

if [[ -z "${ENV_FILE}" || ! -f "${ENV_FILE}" || -z "${SERVICE}" ]]; then
  echo "Usage: $0 inventory/homelab.env <service>"
  echo "Services: postgresql|redis|mongodb|rabbitmq|qdrant|kafka"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

DB_ROOT="${DB_ROOT:-${STORAGE_ROOT}/db}"
UID_SHIFT_BASE="${UID_SHIFT_BASE:-100000}"

case "${SERVICE}" in
  postgresql) CTID="${POSTGRES_CTID:-}"; USER="postgres"; HOST_PATH="${DB_ROOT}/postgresql" ;;
  redis)      CTID="${REDIS_CTID:-}";    USER="redis";   HOST_PATH="${DB_ROOT}/redis"      ;;
  mongodb)    CTID="${MONGO_CTID:-}";    USER="mongodb"; HOST_PATH="${DB_ROOT}/mongodb"    ;;
  rabbitmq)   CTID="${RABBIT_CTID:-}";   USER="rabbitmq";HOST_PATH="${DB_ROOT}/rabbitmq"   ;;
  qdrant)     CTID="${QDRANT_CTID:-}";   USER="qdrant";  HOST_PATH="${DB_ROOT}/qdrant"     ;;
  kafka)      CTID="${KAFKA_CTID:-}";    USER="kafka";   HOST_PATH="${DB_ROOT}/kafka"      ;;
  *) echo "Unknown service: ${SERVICE}"; exit 1 ;;
esac

if [[ -z "${CTID}" ]]; then
  echo "CTID for ${SERVICE} is empty. Check inventory."
  exit 1
fi

UID="$(pct exec "${CTID}" -- id -u "${USER}")"
GID="$(pct exec "${CTID}" -- id -g "${USER}")"
SHIFTED_UID="$((UID_SHIFT_BASE + UID))"
SHIFTED_GID="$((UID_SHIFT_BASE + GID))"

echo "[*] ${SERVICE}: container UID:GID=${UID}:${GID} -> shifted ${SHIFTED_UID}:${SHIFTED_GID}"
echo "    chown -R ${SHIFTED_UID}:${SHIFTED_GID} ${HOST_PATH}"
chown -R "${SHIFTED_UID}:${SHIFTED_GID}" "${HOST_PATH}"
echo "[✓] Done."
