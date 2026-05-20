#!/bin/bash
set -euo pipefail

SSH_PORT="${1:?usage: workspace-infra-entrypoint.sh <sshd 监听端口>}"

/usr/local/bin/workspace-ssh-volume-init.sh

bootstrap_rc=0
/usr/local/bin/workspace-bootstrap.sh || bootstrap_rc=$?

if [ "${bootstrap_rc}" -ne 0 ]; then
  echo "workspace-infra-entrypoint: bootstrap 失败（退出码=${bootstrap_rc}），仍将启动 sshd。常见原因：.env 未配置 NEXTGIRL_GIT_URL / INTELINK_GIT_URL / FUTURIST_GIT_URL。" >&2
fi

exec /usr/sbin/sshd -D -e -p "${SSH_PORT}"
