#!/usr/bin/env bash
set -euo pipefail

STORAGE_ROOT="${STORAGE_ROOT:-/srv/storage}"
DB_ROOT="${DB_ROOT:-${STORAGE_ROOT}/db}"

echo "[*] Creating folder structure under: ${DB_ROOT}"
sudo mkdir -p "${DB_ROOT}"/{postgresql,redis,qdrant,rabbitmq,kafka,mongodb,elasticsearch}

echo "[*] Baseline permissions for unprivileged LXC (refined later per-service)"
sudo chown -R 100000:100000 "${DB_ROOT}" || true
sudo chmod -R 750 "${DB_ROOT}"

echo "[✓] Done."
