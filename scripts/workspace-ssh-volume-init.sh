#!/bin/bash
set -euo pipefail

SSH_DIR="/home/admin/.ssh"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

install -d -m 0700 -o admin -g admin "${SSH_DIR}"

if [ ! -f "${SSH_DIR}/authorized_keys" ]; then
  install -m 0600 -o admin -g admin /dev/null "${SSH_DIR}/authorized_keys"
else
  chown admin:admin "${SSH_DIR}/authorized_keys"
  chmod 0600 "${SSH_DIR}/authorized_keys"
fi

# git@github.com clone 需要 known_hosts，否则 Host key verification failed
touch "${KNOWN_HOSTS}"
chown admin:admin "${KNOWN_HOSTS}"
chmod 0644 "${KNOWN_HOSTS}"

if ! grep -q '^github\.com ' "${KNOWN_HOSTS}" 2>/dev/null; then
  echo "[workspace-ssh-volume-init] 写入 github.com 到 known_hosts"
  ssh-keyscan -t ed25519,rsa github.com >>"${KNOWN_HOSTS}" 2>/dev/null
  chown admin:admin "${KNOWN_HOSTS}"
fi
