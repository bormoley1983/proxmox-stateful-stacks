#!/usr/bin/env bash
set -euo pipefail

# Optional: accept inventory file to source variables (e.g., N8N_CTID)
ENV_FILE="${1:-}"
if [[ -n "${ENV_FILE}" && -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

STORAGE_ROOT="${STORAGE_ROOT:-/srv/storage}"
DB_ROOT="${DB_ROOT:-${STORAGE_ROOT}/db}"

echo "[*] Creating folder structure under: ${DB_ROOT}"
sudo mkdir -p "${DB_ROOT}"/{postgresql,redis,qdrant,rabbitmq,kafka,mongodb,elasticsearch}

# Optional: n8n storage (if N8N_CTID is set in env)
if [[ -n "${N8N_CTID:-}" ]]; then
  echo "[*] Creating n8n storage directories..."
  sudo mkdir -p "${STORAGE_ROOT}/services/n8n"/{n8n_data,files,backups,caddy_config,caddy}
fi

echo "[*] Baseline permissions for unprivileged LXC (refined later per-service)"
sudo chown -R 100000:100000 "${DB_ROOT}" || true
sudo chmod -R 750 "${DB_ROOT}"

# Apply baseline permissions to n8n storage if it was created
if [[ -n "${N8N_CTID:-}" && -d "${STORAGE_ROOT}/services/n8n" ]]; then
  echo "[*] Applying baseline permissions to n8n storage..."
  sudo chown -R 100000:100000 "${STORAGE_ROOT}/services/n8n" || true
  sudo chmod -R 750 "${STORAGE_ROOT}/services/n8n"
fi

echo "[✓] Done."
