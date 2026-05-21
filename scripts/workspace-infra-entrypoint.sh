#!/bin/bash
set -euo pipefail

SSH_PORT="${1:?usage: workspace-infra-entrypoint.sh <sshd 监听端口>}"
LOG_DIR="/var/log/workspace-infra"
LOG_FILE="${LOG_DIR}/startup.log"

log() {
  local line="[$(date -Iseconds)] [dev-entrypoint] $*"
  echo "$line" >&2
  if [[ -d "$LOG_DIR" && -w "$LOG_DIR" ]]; then
    echo "$line" >>"$LOG_FILE"
  fi
}

log "========== 容器启动 =========="
log "sshd 将监听端口: ${SSH_PORT}"

/usr/local/bin/workspace-ssh-volume-init.sh 2>&1 | while read -r line; do log "$line"; done

log "--- /home/admin/work 挂载与内容 ---"
if command -v findmnt >/dev/null 2>&1; then
  findmnt -T /home/admin/work 2>&1 | while read -r line; do log "findmnt: $line"; done || log "findmnt: 无法解析挂载"
else
  mount 2>/dev/null | grep -F '/home/admin/work' | while read -r line; do log "mount: $line"; done || true
fi

WORK_ITEMS="$(ls -A /home/admin/work 2>/dev/null | wc -l)"
log "work 目录条目数: ${WORK_ITEMS}"
ls -la /home/admin/work 2>&1 | while read -r line; do log "  $line"; done

if [[ "${WORK_ITEMS}" -eq 0 ]]; then
  log "!!! WORK 为空 !!!"
  log "代码不会自动出现。在宿主机执行："
  log "  cd ~/workspace-infra && mkdir -p work"
  log "  cd work && git clone git@github.com:neverload/nextgirl.git"
  log "  cd work && git clone git@github.com:neverload/intelink.git"
  log "  cd work && git clone git@github.com:neverload/futurist.git"
  log "bind 挂载: 宿主机 ~/workspace-infra/work = 容器 /home/admin/work"
  log "改完宿主机 work/ 后无需 restart，容器内立即可见"
else
  log "work 非空，挂载正常"
fi

log "--- sshd 启动 ---"
exec /usr/sbin/sshd -D -e -p "${SSH_PORT}"
