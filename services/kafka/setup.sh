#!/usr/bin/env bash
set -euo pipefail

apt update
apt install -y default-jre-headless curl tar

KAFKA_VER="${KAFKA_VER:-4.1.1}"
SCALA_VER="${SCALA_VER:-2.13}"

useradd -r -s /usr/sbin/nologin kafka 2>/dev/null || true

cd /opt
if [[ ! -d "kafka_${SCALA_VER}-${KAFKA_VER}" ]]; then
  curl -L -o kafka.tgz "https://downloads.apache.org/kafka/${KAFKA_VER}/kafka_${SCALA_VER}-${KAFKA_VER}.tgz"
  tar -xzf kafka.tgz
  rm -f kafka.tgz
fi

ln -sfn "kafka_${SCALA_VER}-${KAFKA_VER}" kafka
chown -R kafka:kafka /opt/kafka /opt/kafka_*

mkdir -p /opt/kafka/config/kraft

KAFKA_CLUSTER_ID="$(/opt/kafka/bin/kafka-storage.sh random-uuid)"
LAN_IP="${KAFKA_IP:-$(hostname -I | awk '{print $1}')}"

cat > /opt/kafka/config/kraft/server.properties <<EOF
node.id=1
process.roles=broker,controller
listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
advertised.listeners=PLAINTEXT://${LAN_IP}:9092
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
controller.listener.names=CONTROLLER
controller.quorum.voters=1@${LAN_IP}:9093
inter.broker.listener.name=PLAINTEXT
log.dirs=/var/lib/kafka
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1
num.partitions=1
EOF

/opt/kafka/bin/kafka-storage.sh format -t "${KAFKA_CLUSTER_ID}" -c /opt/kafka/config/kraft/server.properties

cat > /etc/systemd/system/kafka.service <<'EOF'
[Unit]
Description=Apache Kafka (KRaft)
After=network.target

[Service]
User=kafka
Group=kafka
Environment="KAFKA_HEAP_OPTS=-Xms1G -Xmx2G"
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/kraft/server.properties
Restart=always
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kafka
sleep 2
/opt/kafka/bin/kafka-topics.sh --bootstrap-server "${LAN_IP}:9092" --list || true
echo "[✓] Kafka installed."
