#!/usr/bin/env bash
set -euo pipefail

apt update
apt install -y ca-certificates curl gnupg

KEYRING="/usr/share/keyrings/mongodb-server.gpg"
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | gpg --dearmor -o "${KEYRING}"

CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
echo "deb [ signed-by=${KEYRING} ] https://repo.mongodb.org/apt/debian ${CODENAME}/mongodb-org/8.0 main"   > /etc/apt/sources.list.d/mongodb-org.list

apt update
apt install -y mongodb-org

systemctl enable --now mongod
mongosh --eval "db.runCommand({ ping: 1 })" || true

echo "[✓] MongoDB installed. Next: create admin user and enable auth as needed."
