#!/bin/bash
# 宿主机 ~/workspace-infra 下执行：./scripts/load-work.sh
# 直接写入 Docker 卷 workspace_infra_work_data，不依赖容器内 pull、不用 docker cp
set -euo pipefail

VOLUME_NAME="${WORK_VOLUME:-workspace_infra_work_data}"

NEXTGIRL_GIT_URL="${NEXTGIRL_GIT_URL:-git@github.com:neverload/nextgirl.git}"
INTELINK_GIT_URL="${INTELINK_GIT_URL:-git@github.com:neverload/intelink.git}"
FUTURIST_GIT_URL="${FUTURIST_GIT_URL:-git@github.com:neverload/futurist.git}"

die() {
  echo "load-work.sh: $*" >&2
  exit 1
}

command -v docker >/dev/null || die "需要 docker"
command -v git >/dev/null || die "需要 git"

WORK_ROOT="$(docker volume inspect "$VOLUME_NAME" --format '{{.Mountpoint}}' 2>/dev/null)" || \
  die "卷 ${VOLUME_NAME} 不存在，先 docker compose up -d dev 创建卷"

# 容器内 admin 的 uid（默认 1000）
ADMIN_UID="${ADMIN_UID:-1000}"
if docker ps --format '{{.Names}}' | grep -qx dev; then
  ADMIN_UID="$(docker exec dev id -u admin 2>/dev/null || echo 1000)"
fi

SSH_DIR="${HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if ! grep -q '^github\.com ' "${SSH_DIR}/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519,rsa github.com >>"${SSH_DIR}/known_hosts"
  chmod 644 "${SSH_DIR}/known_hosts"
fi
export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${SSH_DIR}/known_hosts"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

sync_one() {
  local name="$1"
  local url="$2"
  local dest="${WORK_ROOT}/${name}"

  if [[ -d "${dest}/.git" ]]; then
    echo "==> ${name}: 卷里已有，跳过"
    return 0
  fi

  if [[ -e "$dest" ]]; then
    die "${dest} 已存在但不是 git 仓库"
  fi

  echo "==> ${name}: clone（临时目录）"
  git clone "$url" "${TMP}/${name}"

  echo "==> ${name}: 写入卷 ${dest}"
  sudo mkdir -p "$WORK_ROOT"
  sudo mv "${TMP}/${name}" "$dest"
  sudo chown -R "${ADMIN_UID}:${ADMIN_UID}" "$dest"
}

echo "卷路径: ${WORK_ROOT} （容器内即 /home/admin/work）"

sync_one nextgirl "$NEXTGIRL_GIT_URL"
sync_one intelink "$INTELINK_GIT_URL"
sync_one futurist "$FUTURIST_GIT_URL"

echo "完成。卷内容："
sudo ls -la "$WORK_ROOT"

if docker ps --format '{{.Names}}' | grep -qx dev; then
  echo "容器内："
  docker exec dev ls -la /home/admin/work
fi
