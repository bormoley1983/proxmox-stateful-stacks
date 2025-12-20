#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${USER_NAME:-sudo_user}"

apt update
apt install -y sudo openssh-server

if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${USER_NAME}"
fi

usermod -aG sudo "${USER_NAME}"

SSHD_CFG="/etc/ssh/sshd_config"
grep -q '^PermitRootLogin' "${SSHD_CFG}" && sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CFG}" || echo "PermitRootLogin no" >> "${SSHD_CFG}"
grep -q '^PasswordAuthentication' "${SSHD_CFG}" && sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "${SSHD_CFG}" || echo "PasswordAuthentication yes" >> "${SSHD_CFG}"

systemctl restart ssh || systemctl restart sshd

echo "[✓] User + SSH configured. Add your public key to /home/${USER_NAME}/.ssh/authorized_keys, then set PasswordAuthentication no."
