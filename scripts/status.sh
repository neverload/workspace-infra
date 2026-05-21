#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_WORK="/home/admin/work"

echo "========== status $(date -Iseconds) =========="
echo "目录: $ROOT"
echo ""

echo "--- ${HOST_WORK} ---"
if [[ -d "$HOST_WORK" ]]; then
  ls -la "$HOST_WORK"
  echo "条目: $(ls -A "$HOST_WORK" 2>/dev/null | wc -l)"
else
  echo "!!! 不存在"
fi
echo ""

if ! docker ps -a --format '{{.Names}}' | grep -qx dev; then
  echo "dev 容器不存在"
  exit 0
fi

echo "--- dev ---"
echo "状态: $(docker inspect dev --format '{{.State.Status}}')"
if docker ps --format '{{.Names}}' | grep -qx dev; then
  echo "work:"
  docker exec dev ls -la "$HOST_WORK" 2>&1
  echo ""
  echo "--- pull 日志 ---"
  docker exec dev grep '\[pull\]\|git 同步' /var/log/workspace-infra/startup.log 2>&1 | tail -20 || true
fi
