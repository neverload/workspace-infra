#!/bin/bash
set -euo pipefail

WORK="${WORK_DIR:?WORK_DIR 未设置}"

log() {
  echo "[$(date -Iseconds)] [pull] $*"
}

die() {
  log "错误: $*"
  exit 1
}

[[ "$(id -un)" == "admin" ]] || die "须以 admin 运行（entrypoint 会用 sudo -u admin 调用）"

: "${NEXTGIRL_GIT_URL:?NEXTGIRL_GIT_URL 未设置}"
: "${NEXTGIRL_GIT_BRANCH:?NEXTGIRL_GIT_BRANCH 未设置}"
: "${INTELINK_GIT_URL:?INTELINK_GIT_URL 未设置}"
: "${INTELINK_GIT_BRANCH:?INTELINK_GIT_BRANCH 未设置}"
: "${FUTURIST_GIT_URL:?FUTURIST_GIT_URL 未设置}"
: "${FUTURIST_GIT_BRANCH:?FUTURIST_GIT_BRANCH 未设置}"

log "工作目录: ${WORK}"
mkdir -p "$WORK"
cd "$WORK"

SSH_DIR="${HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if ! grep -q '^github\.com ' "${SSH_DIR}/known_hosts" 2>/dev/null; then
  log "写入 github.com known_hosts"
  ssh-keyscan -t ed25519,rsa github.com >>"${SSH_DIR}/known_hosts"
  chmod 644 "${SSH_DIR}/known_hosts"
fi

if [[ ! -f "${SSH_DIR}/id_ed25519" && ! -f "${SSH_DIR}/id_rsa" ]]; then
  die "无 ~/.ssh/id_ed25519：容器内 ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519，公钥加到 GitHub"
fi

export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${SSH_DIR}/known_hosts"

sync_one() {
  local name="$1"
  local url="$2"
  local branch="$3"
  local dir="${WORK}/${name}"
  local t0=$SECONDS

  if [[ -d "${dir}/.git" ]]; then
    log "${name}: fetch origin/${branch} → ${url}"
    git -C "$dir" fetch origin "$branch"
    git -C "$dir" checkout -B "$branch" "origin/${branch}"
    git -C "$dir" reset --hard "origin/${branch}"
    log "${name}: 同步完成，耗时 $((SECONDS - t0))s"
    return
  fi

  [[ -d "$dir" ]] && die "${dir} 存在但不是 git 仓库，先 rm -rf ${dir}"

  log "${name}: git clone -b ${branch} → ${url}"
  git clone -b "$branch" "$url" "$dir"
  log "${name}: clone 完成，耗时 $((SECONDS - t0))s"
}

log "========== 开始同步三仓库 =========="
sync_one nextgirl "$NEXTGIRL_GIT_URL" "$NEXTGIRL_GIT_BRANCH"
sync_one intelink "$INTELINK_GIT_URL" "$INTELINK_GIT_BRANCH"
sync_one futurist "$FUTURIST_GIT_URL" "$FUTURIST_GIT_BRANCH"
log "========== 同步结束 =========="
ls -la "$WORK"
