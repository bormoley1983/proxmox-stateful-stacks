#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-}"
if [[ -z "${ENV_FILE}" || ! -f "${ENV_FILE}" ]]; then
  echo "Usage: $0 inventory/homelab.env"
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

DB_ROOT="${DB_ROOT:-${STORAGE_ROOT}/db}"

echo "[*] Using DB_ROOT=${DB_ROOT}"
echo "[*] Binding mounts into LXCs"

bind() {
  local ctid="$1"
  local host_path="$2"
  local mp_path="$3"
  if [[ -z "${ctid}" ]]; then
    echo "[-] Skip (empty CTID) for ${host_path}"
    return 0
  fi
  echo "    pct set ${ctid} -mp0 ${host_path},mp=${mp_path}"
  pct set "${ctid}" -mp0 "${host_path}",mp="${mp_path}"
}

bind "${POSTGRES_CTID:-}" "${DB_ROOT}/postgresql" "/var/lib/postgresql/17/main"
bind "${REDIS_CTID:-}"    "${DB_ROOT}/redis"      "/var/lib/redis"
bind "${MONGO_CTID:-}"    "${DB_ROOT}/mongodb"    "/var/lib/mongodb"
bind "${RABBIT_CTID:-}"   "${DB_ROOT}/rabbitmq"   "/var/lib/rabbitmq"
bind "${QDRANT_CTID:-}"   "${DB_ROOT}/qdrant"     "/var/lib/qdrant"
bind "${KAFKA_CTID:-}"    "${DB_ROOT}/kafka"      "/var/lib/kafka"

echo "[✓] Done."
