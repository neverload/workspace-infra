#!/bin/bash
set -euo pipefail

SSH_PORT="${1:?usage: workspace-infra-entrypoint.sh <sshd 监听端口>}"
LOG_DIR="/var/log/workspace-infra"
LOG_FILE="${LOG_DIR}/startup.log"

log() {
  local line="[$(date -Iseconds)] [entrypoint] $*"
  echo "$line" >&2
  if [[ -d "$LOG_DIR" && -w "$LOG_DIR" ]]; then
    echo "$line" >>"$LOG_FILE"
  fi
}

log "========== 容器启动 =========="
log "sshd 端口: ${SSH_PORT}"

/usr/local/bin/workspace-ssh-volume-init.sh 2>&1 | while read -r line; do log "$line"; done

mkdir -p /home/admin/work
chown -R admin:admin /home/admin/work
chmod 755 /home/admin/work
log "/home/admin/work 权限: $(stat -c '%U:%G %a' /home/admin/work)（含子目录已 chown -R）"

log "--- 挂载 /home/admin/work ---"
if command -v findmnt >/dev/null 2>&1; then
  findmnt -T /home/admin/work 2>&1 | while read -r line; do log "findmnt: $line"; done || true
fi

run_pull() {
  local pull_out pull_rc work_items
  pull_out="$(mktemp)"
  set +e
  sudo -u admin -H /bin/bash /usr/local/bin/pull >"$pull_out" 2>&1
  pull_rc=$?
  set -e
  while read -r line; do log "$line"; done <"$pull_out"
  rm -f "$pull_out"
  if [[ "$pull_rc" -ne 0 ]]; then
    log "!!! git 同步失败 exit=${pull_rc} — 见上方 [pull] 日志"
    log "!!! 常见原因: 无 GitHub SSH 私钥；或 /home/admin/work 权限非 admin"
  else
    log "git 同步成功"
  fi
  work_items="$(ls -A /home/admin/work 2>/dev/null | wc -l)"
  log "work 条目数: ${work_items}"
  ls -la /home/admin/work 2>&1 | while read -r line; do log "  $line"; done
}

log "========== git 同步（后台 pull，clone 可能数分钟；sshd 不等待）=========="
if [[ "${RUN_GIT_SYNC}" == "1" ]] && [[ -f /usr/local/bin/pull ]]; then
  run_pull &
  log "git 同步 pid=$! — 进度: docker logs -f dev 或 tail -f logs/startup.log"
else
  log "跳过 git 同步（仅 dev 容器 RUN_GIT_SYNC=1 时执行）"
  WORK_ITEMS="$(ls -A /home/admin/work 2>/dev/null | wc -l)"
  log "work 条目数: ${WORK_ITEMS}"
  ls -la /home/admin/work 2>&1 | while read -r line; do log "  $line"; done
fi

log "--- sshd 启动 ---"
exec /usr/sbin/sshd -D -e -p "${SSH_PORT}"
