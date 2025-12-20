#!/usr/bin/env bash
set -euo pipefail

apt update
apt install -y redis-server

CONF="/etc/redis/redis.conf"
LAN_IP="${REDIS_IP:-127.0.0.1}"
REDIS_PASS="${DEFAULT_DB_PASS:-CHANGEME}"

# bind
if grep -q "^bind " "${CONF}"; then
  sed -i "s/^bind .*/bind 127.0.0.1 ${LAN_IP}/" "${CONF}"
else
  echo "bind 127.0.0.1 ${LAN_IP}" >> "${CONF}"
fi

# requirepass
if grep -q "^#\?requirepass" "${CONF}"; then
  sed -i "s/^#\?requirepass .*/requirepass ${REDIS_PASS}/" "${CONF}"
else
  echo "requirepass ${REDIS_PASS}" >> "${CONF}"
fi

grep -q "^appendonly" "${CONF}" && sed -i "s/^appendonly .*/appendonly yes/" "${CONF}" || echo "appendonly yes" >> "${CONF}"
grep -q "^dir " "${CONF}" && sed -i "s|^dir .*|dir /var/lib/redis|" "${CONF}" || echo "dir /var/lib/redis" >> "${CONF}"

SERVICE_FILE="/usr/lib/systemd/system/redis-server.service"
if [[ -f "${SERVICE_FILE}" ]]; then
  if grep -q "^PrivateUsers=" "${SERVICE_FILE}"; then
    sed -i "s/^PrivateUsers=.*/PrivateUsers=false/" "${SERVICE_FILE}"
  else
    echo "PrivateUsers=false" >> "${SERVICE_FILE}"
  fi
  systemctl daemon-reload
fi

systemctl enable --now redis-server
systemctl restart redis-server

redis-cli -a "${REDIS_PASS}" ping || true
echo "[✓] Redis installed."
