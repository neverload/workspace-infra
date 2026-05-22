#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="/home/admin/work"

echo "========== status $(date -Iseconds) =========="
echo "compose: $ROOT"
echo "代码目录: 容器卷 work-data → ${WORK}（宿主机无源码）"
echo ""

if ! docker ps -a --format '{{.Names}}' | grep -qx dev; then
  echo "dev 容器不存在"
  exit 0
fi

echo "--- dev $(docker inspect dev --format '{{.State.Status}}') ---"
if docker ps --format '{{.Names}}' | grep -qx dev; then
  docker exec dev ls -la "$WORK" 2>&1
  for repo in nextgirl intelink futurist; do
    if docker exec dev test -d "${WORK}/${repo}/.git" 2>/dev/null; then
      n="$(docker exec dev git -C "${WORK}/${repo}" ls-files 2>/dev/null | wc -l)"
      echo "  ${repo}: ${n} 文件"
    else
      echo "  ${repo}: 缺失"
    fi
  done
  echo ""
  docker exec dev grep '\[pull\]\|git 同步' /var/log/workspace-infra/startup.log 2>&1 | tail -20 || true
fi

echo ""
echo "--- prod $(docker inspect prod --format '{{.State.Status}}' 2>/dev/null || echo 无) ---"
if docker ps --format '{{.Names}}' | grep -qx prod; then
  docker exec prod ls -la "$WORK" 2>&1 | head -5
fi
