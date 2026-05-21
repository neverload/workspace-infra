#!/bin/bash
set -euo pipefail

SSH_PORT="${1:?usage: workspace-infra-entrypoint.sh <sshd 监听端口>}"
LOG_DIR="/var/log/workspace-infra"
LOG_FILE="${LOG_DIR}/startup.log"
WORK="/home/admin/work"
SSH_DIR="/home/admin/.ssh"

log() {
  local line="[$(date -Iseconds)] [entrypoint] $*"
  echo "$line" >&2
  if [[ -d "$LOG_DIR" && -w "$LOG_DIR" ]]; then
    echo "$line" >>"$LOG_FILE"
  fi
}

init_ssh() {
  local known_hosts="${SSH_DIR}/known_hosts"
  install -d -m 0700 -o admin -g admin "${SSH_DIR}"
  if [[ ! -f "${SSH_DIR}/authorized_keys" ]]; then
    install -m 0600 -o admin -g admin /dev/null "${SSH_DIR}/authorized_keys"
  else
    chown admin:admin "${SSH_DIR}/authorized_keys"
    chmod 0600 "${SSH_DIR}/authorized_keys"
  fi
  touch "${known_hosts}"
  chown admin:admin "${known_hosts}"
  chmod 0644 "${known_hosts}"
  if ! grep -q '^github\.com ' "${known_hosts}" 2>/dev/null; then
    log "写入 github.com known_hosts"
    ssh-keyscan -t ed25519,rsa github.com >>"${known_hosts}"
    chown admin:admin "${known_hosts}"
  fi
}

log_work() {
  local work_items
  work_items="$(ls -A "$WORK" 2>/dev/null | wc -l)"
  log "work 条目数: ${work_items}"
  ls -la "$WORK" 2>&1 | while read -r line; do log "  $line"; done
}

run_pull() {
  local pull_out pull_rc
  pull_out="$(mktemp)"
  set +e
  sudo -u admin -H /bin/bash /usr/local/bin/pull >"$pull_out" 2>&1
  pull_rc=$?
  set -e
  while read -r line; do log "$line"; done <"$pull_out"
  rm -f "$pull_out"
  if [[ "$pull_rc" -ne 0 ]]; then
    log "!!! git 同步失败 exit=${pull_rc}"
  else
    log "git 同步成功"
  fi
  log_work
}

log "========== 容器启动 =========="
log "sshd 端口: ${SSH_PORT}"

init_ssh

mkdir -p "$WORK"
chown -R admin:admin "$WORK"
chmod 755 "$WORK"
log "${WORK} 权限: $(stat -c '%U:%G %a' "$WORK")"

if [[ "${RUN_GIT_SYNC}" == "1" ]]; then
  log "git 同步（后台）— tail -f logs/startup.log"
  run_pull &
  log "git 同步 pid=$!"
else
  log_work
fi

log "sshd 启动"
exec /usr/sbin/sshd -D -e -p "${SSH_PORT}"
