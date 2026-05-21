#!/bin/bash
set -euo pipefail

log() {
  echo "[workspace-bootstrap] $*"
}

require_env() {
  local n="$1"
  if [ -z "${!n:-}" ]; then
    echo "workspace-bootstrap: 缺少环境变量 $n（请在 workspace-infra/.env 中设置）" >&2
    exit 1
  fi
}

require_env NEXTGIRL_GIT_URL
require_env INTELINK_GIT_URL
require_env FUTURIST_GIT_URL

WORK="/home/admin/work"
mkdir -p "$WORK"
chown admin:admin "$WORK"

# 配置了 GITHUB_TOKEN 时用 HTTPS 克隆，全程非交互，不依赖 SSH 密钥与 known_hosts。
resolve_clone_url() {
  local url="$1"
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "$url"
    return
  fi
  if [[ "$url" =~ ^git@github.com:(.+)$ ]]; then
    echo "https://x-access-token:${GITHUB_TOKEN}@github.com/${BASH_REMATCH[1]}"
    return
  fi
  if [[ "$url" =~ ^https://github.com/(.+)$ ]]; then
    echo "https://x-access-token:${GITHUB_TOKEN}@github.com/${BASH_REMATCH[1]}"
    return
  fi
  echo "workspace-bootstrap: 无法为 GITHUB_TOKEN 解析 URL: $url" >&2
  exit 1
}

admin_ssh() {
  sudo -u admin -H env HOME=/home/admin \
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/home/admin/.ssh/known_hosts" \
    "$@"
}

verify_github_ssh() {
  log "检查 admin 的 GitHub SSH（未配置 GITHUB_TOKEN 时使用）"
  ls -la /home/admin/.ssh/ 2>&1 | sed 's/^/[workspace-bootstrap]   /' || true

  if [ ! -f /home/admin/.ssh/id_ed25519 ] && [ ! -f /home/admin/.ssh/id_rsa ]; then
    echo "workspace-bootstrap: 未配置 GITHUB_TOKEN，且未找到 ~/.ssh/id_ed25519 或 id_rsa。" >&2
    echo "workspace-bootstrap: 推荐在 .env 设置 GITHUB_TOKEN（一次配置，全自动 HTTPS 克隆）。" >&2
    return 1
  fi
  chmod 700 /home/admin/.ssh
  [ -f /home/admin/.ssh/id_ed25519 ] && chmod 600 /home/admin/.ssh/id_ed25519
  [ -f /home/admin/.ssh/id_rsa ] && chmod 600 /home/admin/.ssh/id_rsa
  chown -R admin:admin /home/admin/.ssh

  if admin_ssh ssh -T git@github.com 2>&1 | tee /dev/stderr | grep -qi 'successfully authenticated'; then
    log "GitHub SSH 认证 OK"
    return 0
  fi
  echo "workspace-bootstrap: GitHub SSH 认证失败；建议改用 .env 中的 GITHUB_TOKEN。" >&2
  return 1
}

clone_one() {
  local name="$1"
  local url="$2"
  local dir="$WORK/$name"
  local resolved
  resolved="$(resolve_clone_url "$url")"

  if [ -d "$dir/.git" ]; then
    log "已存在 $dir，跳过 git clone"
    return 0
  fi

  log "git clone $name"
  if [[ "$resolved" == https://* ]]; then
    sudo -u admin -H env HOME=/home/admin GIT_TERMINAL_PROMPT=0 \
      git clone "$resolved" "$dir"
  else
    admin_ssh git clone "$resolved" "$dir"
  fi
}

if [ -n "${GITHUB_TOKEN:-}" ]; then
  log "已配置 GITHUB_TOKEN，使用 HTTPS 非交互克隆"
else
  verify_github_ssh
fi

clone_one nextgirl "$NEXTGIRL_GIT_URL"
clone_one intelink "$INTELINK_GIT_URL"
clone_one futurist "$FUTURIST_GIT_URL"

MARKER="$WORK/.workspace-infra-deps-done"
if [ -f "$MARKER" ]; then
  log "依赖已安装（$MARKER 存在），跳过 venv/yarn/pip。删除该文件可强制重装依赖。"
  exit 0
fi

run_admin() {
  sudo -u admin -H env HOME=/home/admin PATH="/home/admin/.local/bin:${PATH}" bash -lc "$1"
}

log "安装前端依赖（yarn）…"
run_admin 'set -e; cd /home/admin/work/nextgirl/web && yarn install'
run_admin 'set -e; cd /home/admin/work/intelink/web && yarn install'
run_admin 'set -e; cd /home/admin/work/futurist/web && yarn install'

log "后端：在各仓库 server/.venv 中执行 pip install -r …"

run_admin 'set -euo pipefail
  cd /home/admin/work/nextgirl/server
  if [ ! -x .venv/bin/python ]; then python3.13 -m venv .venv; fi
  ./.venv/bin/pip install -U pip setuptools wheel
  ./.venv/bin/pip install -r requirements.txt -r requirements-dev.txt'

run_admin 'set -euo pipefail
  cd /home/admin/work/intelink/server
  if [ ! -x .venv/bin/python ]; then python3.13 -m venv .venv; fi
  ./.venv/bin/pip install -U pip setuptools wheel
  ./.venv/bin/pip install -r requirements.txt -r requirements-dev.txt'

run_admin 'set -euo pipefail
  cd /home/admin/work/futurist/server
  if [ ! -x .venv/bin/python ]; then python3.13 -m venv .venv; fi
  ./.venv/bin/pip install -U pip setuptools wheel
  ./.venv/bin/pip install -r requirements-dev.txt'

touch "$MARKER"
chown admin:admin "$MARKER"
log "依赖安装完成（各仓库 server/.venv）；已写入 $MARKER"
