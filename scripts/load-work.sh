#!/bin/bash
# 在宿主机 workspace-infra 目录执行：./scripts/load-work.sh
# 临时 clone → docker cp 进容器 → 删除宿主机临时目录
set -euo pipefail

CONTAINER="${CONTAINER:-dev}"
WORK_IN_CONTAINER="/home/admin/work"

NEXTGIRL_GIT_URL="${NEXTGIRL_GIT_URL:-git@github.com:neverload/nextgirl.git}"
INTELINK_GIT_URL="${INTELINK_GIT_URL:-git@github.com:neverload/intelink.git}"
FUTURIST_GIT_URL="${FUTURIST_GIT_URL:-git@github.com:neverload/futurist.git}"

die() {
  echo "load-work.sh: $*" >&2
  exit 1
}

command -v docker >/dev/null || die "需要 docker"
command -v git >/dev/null || die "需要 git"

docker inspect "$CONTAINER" >/dev/null 2>&1 || die "容器 ${CONTAINER} 未运行"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SSH_DIR="${HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if ! grep -q '^github\.com ' "${SSH_DIR}/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519,rsa github.com >>"${SSH_DIR}/known_hosts"
  chmod 644 "${SSH_DIR}/known_hosts"
fi
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${SSH_DIR}/known_hosts"

copy_one() {
  local name="$1"
  local url="$2"
  local src="${TMP}/${name}"
  local dst="${WORK_IN_CONTAINER}/${name}"

  if docker exec "$CONTAINER" test -d "${dst}/.git" 2>/dev/null; then
    echo "==> ${name}: 容器内已有，跳过"
    return 0
  fi

  if docker exec "$CONTAINER" test -e "$dst" 2>/dev/null; then
    die "容器内 ${dst} 已存在但不是 git 仓库"
  fi

  echo "==> ${name}: 宿主机 clone"
  git clone "$url" "$src"

  echo "==> ${name}: docker cp → ${CONTAINER}:${dst}"
  docker cp "$src" "${CONTAINER}:${dst}"
  docker exec -u root "$CONTAINER" chown -R admin:admin "$dst"
}

copy_one nextgirl "$NEXTGIRL_GIT_URL"
copy_one intelink "$INTELINK_GIT_URL"
copy_one futurist "$FUTURIST_GIT_URL"

echo "完成。容器内："
docker exec "$CONTAINER" ls -la "$WORK_IN_CONTAINER"
