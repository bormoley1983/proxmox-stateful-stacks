#!/usr/bin/env bash
set -euo pipefail

echo "[*] Installing Docker and prerequisites..."
apt update
apt install -y ca-certificates curl gnupg passwd redis-tools

if ! command -v docker &> /dev/null; then
  echo "[*] Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sh get-docker.sh
  rm -f get-docker.sh
else
  echo "[*] Docker already installed"
fi

echo "[*] Creating n8n user..."
if ! id -u n8n &> /dev/null; then
  useradd -m -s /bin/bash n8n
  usermod -aG docker n8n
  echo "[✓] n8n user created"
else
  echo "[*] n8n user already exists"
  usermod -aG docker n8n || true
fi

echo "[*] Setting up n8n directory structure..."
# /opt/n8n is local to the container (config files, docker-compose)
mkdir -p /opt/n8n

# /var/lib/n8n is bind-mounted from Proxmox host (created by 00_prepare_storage.sh)
# Subdirectories (n8n_data, files, backups, caddy_config, caddy) already exist on host
# Verify bind mount is set up correctly
if [[ ! -d /var/lib/n8n ]]; then
  echo "[!] ERROR: /var/lib/n8n does not exist. Ensure bind mount is configured on Proxmox host."
  echo "    Run: sudo bash scripts/host/01_bind_mounts.sh inventory/homelab.env"
  exit 1
fi

# Verify required subdirectories exist (created on host by 00_prepare_storage.sh)
REQUIRED_DIRS=("n8n_data" "files" "backups" "caddy_config" "caddy")
MISSING_DIRS=()
for dir in "${REQUIRED_DIRS[@]}"; do
  if [[ ! -d "/var/lib/n8n/${dir}" ]]; then
    MISSING_DIRS+=("${dir}")
  fi
done

if [[ ${#MISSING_DIRS[@]} -gt 0 ]]; then
  echo "[!] ERROR: Missing required directories in /var/lib/n8n/: ${MISSING_DIRS[*]}"
  echo "    Ensure storage is prepared on Proxmox host:"
  echo "    sudo bash scripts/host/00_prepare_storage.sh"
  exit 1
fi

echo "[✓] Bind mount verified: /var/lib/n8n and subdirectories exist"

echo "[*] Generating encryption key..."
ENCRYPTION_KEY=$(openssl rand -base64 32)
echo "[*] Encryption key generated: ${ENCRYPTION_KEY:0:8}..."

# Get configuration from environment or use defaults
N8N_HOST="${N8N_HOST:-n8n.homelab.local}"
N8N_PROTOCOL="${N8N_PROTOCOL:-https}"
N8N_PORT="${N8N_PORT:-5678}"
WEBHOOK_URL="${WEBHOOK_URL:-https://n8n.homelab.local}"
N8N_EDITOR_BASE_URL="${N8N_EDITOR_BASE_URL:-https://n8n.homelab.local}"
GENERIC_TIMEZONE="${GENERIC_TIMEZONE:-Asia/Jerusalem}"
TZ="${TZ:-Asia/Jerusalem}"

# Database configuration
DB_POSTGRESDB_HOST="${DB_POSTGRESDB_HOST:-postgres.homelab.local}"
DB_POSTGRESDB_PORT="${DB_POSTGRESDB_PORT:-5432}"
DB_POSTGRESDB_DATABASE="${DB_POSTGRESDB_DATABASE:-n8n}"
DB_POSTGRESDB_USER="${DB_POSTGRESDB_USER:-n8n}"
DB_POSTGRESDB_PASSWORD="${DB_POSTGRESDB_PASSWORD:-CHANGEME}"

# Redis configuration
QUEUE_BULL_REDIS_HOST="${QUEUE_BULL_REDIS_HOST:-redis.homelab.local}"
QUEUE_BULL_REDIS_PORT="${QUEUE_BULL_REDIS_PORT:-6379}"
QUEUE_BULL_REDIS_DB="${QUEUE_BULL_REDIS_DB:-10}"
QUEUE_BULL_REDIS_USERNAME="${QUEUE_BULL_REDIS_USERNAME:-n8n}"
QUEUE_BULL_REDIS_PASSWORD="${QUEUE_BULL_REDIS_PASSWORD:-CHANGEME}"

echo "[*] Creating .env file..."
cat > /opt/n8n/.env <<EOF
# ===== Core URL (external) =====
N8N_HOST=${N8N_HOST}
N8N_PROTOCOL=${N8N_PROTOCOL}
N8N_PORT=${N8N_PORT}
WEBHOOK_URL=${WEBHOOK_URL}
N8N_EDITOR_BASE_URL=${N8N_EDITOR_BASE_URL}
N8N_PROXY_HOPS=1

# ===== Timezone =====
GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
TZ=${TZ}

# ===== Crypto =====
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}

# ===== Postgres =====
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=${DB_POSTGRESDB_HOST}
DB_POSTGRESDB_PORT=${DB_POSTGRESDB_PORT}
DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}
DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}
DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}

# ===== Queue mode / Redis =====
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
QUEUE_BULL_REDIS_DB=${QUEUE_BULL_REDIS_DB}
QUEUE_BULL_REDIS_USERNAME=${QUEUE_BULL_REDIS_USERNAME}
QUEUE_BULL_REDIS_PASSWORD=${QUEUE_BULL_REDIS_PASSWORD}

# Optional: push manual executions to workers too
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true

# Keep only JS runner; avoid Python runner warnings/features
N8N_RUNNERS_ENABLED=js
EOF

echo "[*] Copying Docker Compose file..."
cp "$(dirname "$0")/docker-compose.yml" /opt/n8n/docker-compose.yml

echo "[*] Copying Caddyfile..."
mkdir -p /var/lib/n8n/caddy_config
cp "$(dirname "$0")/Caddyfile" /var/lib/n8n/caddy_config/Caddyfile

# Update Caddyfile with actual hostname if different
if [[ "${N8N_HOST}" != "n8n.homelab.local" ]]; then
  sed -i "s/n8n.homelab.local/${N8N_HOST}/" /var/lib/n8n/caddy_config/Caddyfile
fi

echo "[*] Setting ownership..."
chown -R n8n:n8n /opt/n8n
chown -R n8n:n8n /var/lib/n8n

echo ""
echo "[✓] n8n setup complete!"
echo ""
echo "[!] IMPORTANT: Before starting n8n, ensure:"
echo "    1. PostgreSQL database and user are created (see below)"
echo "    2. Redis ACL user is created (see below)"
echo "    3. Update /opt/n8n/.env with correct credentials"
echo ""
echo "[*] PostgreSQL setup (run on PostgreSQL container):"
echo "    Option 1 - Use helper script:"
echo "      export DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE}"
echo "      export DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER}"
echo "      export DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}"
echo "      sudo -u postgres bash services/n8n/setup-postgres.sh"
echo ""
echo "    Option 2 - Manual SQL:"
echo "      sudo -u postgres psql <<'SQL'"
echo "      CREATE USER ${DB_POSTGRESDB_USER} WITH ENCRYPTED PASSWORD '${DB_POSTGRESDB_PASSWORD}';"
echo "      CREATE DATABASE ${DB_POSTGRESDB_DATABASE} OWNER ${DB_POSTGRESDB_USER};"
echo "      \\c ${DB_POSTGRESDB_DATABASE}"
echo "      ALTER DATABASE ${DB_POSTGRESDB_DATABASE} OWNER TO ${DB_POSTGRESDB_USER};"
echo "      ALTER SCHEMA public OWNER TO ${DB_POSTGRESDB_USER};"
echo "      GRANT USAGE, CREATE ON SCHEMA public TO ${DB_POSTGRESDB_USER};"
echo "      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${DB_POSTGRESDB_USER};"
echo "      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${DB_POSTGRESDB_USER};"
echo "      GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO ${DB_POSTGRESDB_USER};"
echo "      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${DB_POSTGRESDB_USER};"
echo "      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${DB_POSTGRESDB_USER};"
echo "      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO ${DB_POSTGRESDB_USER};"
echo "      SQL"
echo ""
echo "[*] Redis setup (run on Redis container or from host):"
echo "    Option 1 - Use helper script:"
echo "      export REDIS_ADMIN_PASS='REDIS_ADMIN_PASSWORD'"
echo "      export QUEUE_BULL_REDIS_USERNAME=${QUEUE_BULL_REDIS_USERNAME}"
echo "      export QUEUE_BULL_REDIS_PASSWORD=${QUEUE_BULL_REDIS_PASSWORD}"
echo "      export QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}"
echo "      export QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}"
echo "      bash services/n8n/setup-redis.sh"
echo ""
echo "    Option 2 - Manual command:"
echo "      redis-cli -h ${QUEUE_BULL_REDIS_HOST} -p ${QUEUE_BULL_REDIS_PORT} -a 'REDIS_ADMIN_PASSWORD' \\"
echo "        ACL SETUSER ${QUEUE_BULL_REDIS_USERNAME} on >'${QUEUE_BULL_REDIS_PASSWORD}' ~n8n:* +@all -@dangerous -@admin"
echo ""
echo "[*] To start n8n:"
echo "    cd /opt/n8n"
echo "    docker compose up -d"
echo ""
echo "[*] To check logs:"
echo "    docker logs -f n8n-main"

