#!/bin/bash
set -euo pipefail

ENV_FILE="/etc/workspace-infra/env"
WORK="/home/admin/work"

log() {
  echo "[$(date -Iseconds)] [pull] $*"
}

die() {
  log "错误: $*"
  exit 1
}

repo_ok() {
  local dir="$1"
  [[ -d "${dir}/.git" ]] || return 1
  git -C "$dir" rev-parse --verify HEAD >/dev/null 2>&1 || return 1
  [[ -n "$(git -C "$dir" ls-files | head -1)" ]] || return 1
}

[[ -f "$ENV_FILE" ]] || die "缺少 ${ENV_FILE}"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

[[ "$(id -un)" == "admin" ]] || die "须以 admin 运行"

: "${NEXTGIRL_GIT_URL:?NEXTGIRL_GIT_URL 未设置}"
: "${NEXTGIRL_GIT_BRANCH:?NEXTGIRL_GIT_BRANCH 未设置}"
: "${INTELINK_GIT_URL:?INTELINK_GIT_URL 未设置}"
: "${INTELINK_GIT_BRANCH:?INTELINK_GIT_BRANCH 未设置}"
: "${FUTURIST_GIT_URL:?FUTURIST_GIT_URL 未设置}"
: "${FUTURIST_GIT_BRANCH:?FUTURIST_GIT_BRANCH 未设置}"

mkdir -p "$WORK"
cd "$WORK"

exec 9>"${WORK}/.pull.lock"
flock -n 9 || die "另一个 pull 正在运行"

SSH_DIR="${HOME}/.ssh"
if [[ ! -f "${SSH_DIR}/id_ed25519" && ! -f "${SSH_DIR}/id_rsa" ]]; then
  die "无 ~/.ssh/id_ed25519 — ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519，公钥加到 GitHub"
fi

export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${SSH_DIR}/known_hosts"

sync_one() {
  local name="$1"
  local url="$2"
  local branch="$3"
  local dir="${WORK}/${name}"
  local t0=$SECONDS

  if [[ -d "$dir" ]] && ! repo_ok "$dir"; then
    log "${name}: 删除无效目录 ${dir}"
    rm -rf "$dir"
  fi

  if repo_ok "$dir"; then
    log "${name}: fetch origin/${branch}"
    git -C "$dir" fetch origin "$branch"
    git -C "$dir" checkout -B "$branch" "origin/${branch}"
    git -C "$dir" reset --hard "origin/${branch}"
  else
    log "${name}: clone -b ${branch}（大仓库可能数分钟）"
    git clone --progress -b "$branch" "$url" "$dir"
  fi

  repo_ok "$dir" || die "${name}: 同步后仍为空"
  log "${name}: 完成 $((SECONDS - t0))s，$(git -C "$dir" ls-files | wc -l) 文件"
}

log "========== 同步三仓库 =========="
sync_one nextgirl "$NEXTGIRL_GIT_URL" "$NEXTGIRL_GIT_BRANCH"
sync_one intelink "$INTELINK_GIT_URL" "$INTELINK_GIT_BRANCH"
sync_one futurist "$FUTURIST_GIT_URL" "$FUTURIST_GIT_BRANCH"
log "========== 结束 =========="
