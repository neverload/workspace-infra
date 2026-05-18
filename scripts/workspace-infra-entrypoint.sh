#!/bin/bash
set -euo pipefail

SSH_PORT="${1:?usage: workspace-infra-entrypoint.sh <sshd 监听端口>}"

/usr/local/bin/workspace-ssh-volume-init.sh
/usr/local/bin/workspace-bootstrap.sh
exec /usr/sbin/sshd -D -e -p "$SSH_PORT"
