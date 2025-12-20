#!/usr/bin/env bash
set -euo pipefail

apt update
apt install -y rabbitmq-server

systemctl enable --now rabbitmq-server
rabbitmq-plugins enable rabbitmq_management

ADMIN_USER="${DEFAULT_ADMIN_USER:-sudo_user}"
ADMIN_PASS="${DEFAULT_ADMIN_PASS:-CHANGEME}"

rabbitmqctl add_user "${ADMIN_USER}" "${ADMIN_PASS}" 2>/dev/null || true
rabbitmqctl set_user_tags "${ADMIN_USER}" administrator
rabbitmqctl set_permissions -p / "${ADMIN_USER}" ".*" ".*" ".*"

cat > /etc/rabbitmq/rabbitmq.conf <<EOF
loopback_users.guest = false
listeners.tcp.default = 5672
management.tcp.port = 15672
EOF

systemctl restart rabbitmq-server
echo "[✓] RabbitMQ installed. UI: http://<ip>:15672"
