#!/usr/bin/env bash
set -euo pipefail

echo "[!] Template for Debian VM (review before running)."

echo "vm.max_map_count=262144" | tee /etc/sysctl.d/99-elasticsearch.conf
sysctl -p /etc/sysctl.d/99-elasticsearch.conf

apt update
apt install -y ca-certificates curl gnupg

KEYRING="/usr/share/keyrings/elasticsearch-keyring.gpg"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o "${KEYRING}"
echo "deb [signed-by=${KEYRING}] https://artifacts.elastic.co/packages/9.x/apt stable main" > /etc/apt/sources.list.d/elastic-9.x.list

apt update
apt install -y elasticsearch

echo "[*] Edit /etc/elasticsearch/elasticsearch.yml then:"
echo "    systemctl enable --now elasticsearch"
