#!/bin/bash
# 宿主机 ~/workspace-infra 下执行: ./scripts/status.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "========== status $(date -Iseconds) =========="
echo "compose 目录: $ROOT"
echo ""

echo "--- 宿主机 /home/admin/work （代码 clone 在这里）---"
HOST_WORK="/home/admin/work"
if [[ -d "$HOST_WORK" ]]; then
  ls -la "$HOST_WORK"
  echo "条目数: $(ls -A "$HOST_WORK" 2>/dev/null | wc -l)"
  echo "属主: $(stat -c '%U:%G' "$HOST_WORK" 2>/dev/null || echo '?')"
  if [[ "$(stat -c '%U' "$HOST_WORK" 2>/dev/null)" != "admin" ]]; then
    echo "!!! 目录不是 admin 属主，pull 会 Permission denied"
    echo "    修复: sudo chown admin:admin /home/admin/work && docker compose restart dev"
  fi
else
  echo "!!! $HOST_WORK 不存在 — mkdir -p /home/admin/work"
fi
echo ""
echo "（不是 ~/workspace-infra/work，以前配错路径会导致一直空）"
echo ""

echo "--- 容器 dev ---"
if docker ps -a --format '{{.Names}}' | grep -qx dev; then
  echo "状态: $(docker inspect dev --format '{{.State.Status}}')"
  echo "Mounts (work 相关):"
  docker inspect dev --format '{{range .Mounts}}{{if eq .Destination "/home/admin/work"}}{{.Type}} {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}{{end}}'
  if docker ps --format '{{.Names}}' | grep -qx dev; then
    echo "容器内 /home/admin/work:"
    docker exec dev ls -la /home/admin/work 2>&1 || echo "docker exec 失败"
    echo ""
    echo "--- 最近 entrypoint 日志 (docker logs) ---"
    docker logs dev 2>&1 | tail -40
    echo ""
    if docker exec dev test -f /var/log/workspace-infra/startup.log 2>/dev/null; then
      echo "--- startup.log ---"
      docker exec dev cat /var/log/workspace-infra/startup.log 2>&1 | tail -30
    fi
  else
    echo "dev 未运行，上面 Mounts 仍可用；启动: docker compose up -d dev"
  fi
else
  echo "dev 容器不存在"
fi
echo ""
echo "========== 完 =========="
