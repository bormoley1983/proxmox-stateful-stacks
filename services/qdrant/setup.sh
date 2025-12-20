#!/usr/bin/env bash
set -euo pipefail

apt update
apt install -y curl tar

useradd -r -s /usr/sbin/nologin qdrant 2>/dev/null || true
mkdir -p /opt/qdrant /etc/qdrant /var/lib/qdrant
chown -R qdrant:qdrant /etc/qdrant /var/lib/qdrant

cd /opt/qdrant
curl -L -o qdrant.tar.gz https://github.com/qdrant/qdrant/releases/latest/download/qdrant-x86_64-unknown-linux-gnu.tar.gz
tar -xzf qdrant.tar.gz
rm -f qdrant.tar.gz
chown -R qdrant:qdrant /opt/qdrant

cat > /etc/qdrant/config.yaml <<EOF
storage:
  storage_path: /var/lib/qdrant
service:
  host: 0.0.0.0
  http_port: 6333
  grpc_port: 6334
EOF
chown qdrant:qdrant /etc/qdrant/config.yaml

cat > /etc/systemd/system/qdrant.service <<'EOF'
[Unit]
Description=Qdrant
After=network.target

[Service]
User=qdrant
Group=qdrant
WorkingDirectory=/opt/qdrant
ExecStart=/opt/qdrant/qdrant --config-path /etc/qdrant/config.yaml
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now qdrant
curl -fsS http://127.0.0.1:6333/healthz || true
echo "[✓] Qdrant installed."
