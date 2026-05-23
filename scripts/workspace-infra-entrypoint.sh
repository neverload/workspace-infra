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
  local host_authorized_keys="/host-ssh/authorized_keys"

  install -d -m 0700 -o admin -g admin "${SSH_DIR}"

  if [[ ! -f "${host_authorized_keys}" ]]; then
    log "错误: 宿主机 authorized_keys 不存在: ${host_authorized_keys}"
    exit 1
  fi
  install -m 0600 -o admin -g admin "${host_authorized_keys}" "${SSH_DIR}/authorized_keys"
  log "已从宿主机同步 authorized_keys ($(wc -l <"${SSH_DIR}/authorized_keys") 条)"

  touch "${known_hosts}"
  chown admin:admin "${known_hosts}"
  chmod 0644 "${known_hosts}"
  if ! grep -q '^github\.com ' "${known_hosts}" 2>/dev/null; then
    log "写入 github.com known_hosts"
    ssh-keyscan -t ed25519,rsa github.com >>"${known_hosts}"
    chown admin:admin "${known_hosts}"
  fi
}

repo_ok() {
  local dir="$1"
  [[ -d "${dir}/.git" ]] || return 1
  git -C "$dir" rev-parse --verify HEAD >/dev/null 2>&1 || return 1
  [[ -n "$(git -C "$dir" ls-files | head -1)" ]] || return 1
}

all_repos_ok() {
  local name
  for name in nextgirl intelink futurist; do
    repo_ok "${WORK}/${name}" || return 1
  done
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

if [[ "${RUN_GIT_SYNC:-0}" == "1" ]]; then
  if all_repos_ok; then
    log "git 同步（后台更新）"
    run_pull &
    log "git 同步 pid=$!"
  else
    log "git 同步（前台 clone，完成后再开 sshd）"
    run_pull || log "!!! pull 失败，sshd 仍启动"
  fi
else
  log_work
fi

log "sshd 启动"
exec /usr/sbin/sshd -D -e -p "${SSH_PORT}"
