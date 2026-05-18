#!/bin/bash
set -euo pipefail

log() {
  echo "[workspace-bootstrap] $*"
}

require_env() {
  local n="$1"
  if [ -z "${!n:-}" ]; then
    echo "workspace-bootstrap: 缺少环境变量 $n（请在 workspace-infra/.env 中设置远端 Git URL）" >&2
    exit 1
  fi
}

require_env NEXTGIRL_GIT_URL
require_env INTELINK_GIT_URL
require_env FUTURIST_GIT_URL

WORK="/home/admin/work"
mkdir -p "$WORK"
chown admin:admin "$WORK"

clone_one() {
  local name="$1"
  local url="$2"
  local dir="$WORK/$name"
  if [ -d "$dir/.git" ]; then
    log "已存在 $dir，跳过 git clone"
    return 0
  fi
  log "git clone $name"
  git clone "$url" "$dir"
  chown -R admin:admin "$dir"
}

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
