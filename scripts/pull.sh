#!/bin/bash
set -euo pipefail

WORK="${WORK_DIR:-/home/admin/work}"

NEXTGIRL_GIT_URL="${NEXTGIRL_GIT_URL:-git@github.com:neverload/nextgirl.git}"
INTELINK_GIT_URL="${INTELINK_GIT_URL:-git@github.com:neverload/intelink.git}"
FUTURIST_GIT_URL="${FUTURIST_GIT_URL:-git@github.com:neverload/futurist.git}"

die() {
  echo "pull.sh: $*" >&2
  exit 1
}

[[ "$(id -un)" == "admin" ]] || die "用 admin 执行"

mkdir -p "$WORK"
cd "$WORK"

SSH_DIR="${HOME}/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if ! grep -q '^github\.com ' "${SSH_DIR}/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519,rsa github.com >>"${SSH_DIR}/known_hosts"
  chmod 644 "${SSH_DIR}/known_hosts"
fi

export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${SSH_DIR}/known_hosts"

sync_one() {
  local name="$1"
  local url="$2"
  local dir="${WORK}/${name}"

  if [[ -d "${dir}/.git" ]]; then
    echo "==> ${name}: pull"
    git -C "$dir" pull --ff-only
    return
  fi

  [[ -d "$dir" ]] && die "${dir} 存在但不是 git 仓库"

  echo "==> ${name}: clone"
  git clone "$url" "$dir"
}

sync_one nextgirl "$NEXTGIRL_GIT_URL"
sync_one intelink "$INTELINK_GIT_URL"
sync_one futurist "$FUTURIST_GIT_URL"

ls -la "$WORK"
