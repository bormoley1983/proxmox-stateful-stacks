#!/usr/bin/env bash
set -euo pipefail

apt update
apt install -y postgresql postgresql-contrib

systemctl enable --now postgresql

PG_CONF="$(ls -d /etc/postgresql/*/main/postgresql.conf | head -n1)"
HBA_CONF="$(ls -d /etc/postgresql/*/main/pg_hba.conf | head -n1)"

# listen_addresses = '*'
if grep -q "^#\?listen_addresses" "${PG_CONF}"; then
  sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "${PG_CONF}"
else
  echo "listen_addresses = '*'" >> "${PG_CONF}"
fi

LAN_CIDR="${LAN_CIDR:-192.168.0.0/16}"
if ! grep -q "${LAN_CIDR}" "${HBA_CONF}"; then
  echo "host all all ${LAN_CIDR} scram-sha-256" >> "${HBA_CONF}"
fi

systemctl restart postgresql

echo "[✓] PostgreSQL installed. Create users/dbs with sudo -u postgres psql"
