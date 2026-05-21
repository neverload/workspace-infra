#!/bin/bash
# 宿主机 ~/workspace-infra 下执行: ./scripts/status.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "========== status $(date -Iseconds) =========="
echo "compose 目录: $ROOT"
if [[ ! -f "$ROOT/.env" ]]; then
  echo "!!! 缺少 .env — git pull 后应有此文件"
fi
echo ""

echo "--- 宿主机 /home/admin/work （代码 clone 在这里）---"
HOST_WORK="/home/admin/work"
if [[ -d "$HOST_WORK" ]]; then
  ls -la "$HOST_WORK"
  echo "条目数: $(ls -A "$HOST_WORK" 2>/dev/null | wc -l)"
  work_uid="$(stat -c '%u' "$HOST_WORK" 2>/dev/null || echo '')"
  echo "属主: $(stat -c '%U:%G (%u:%g)' "$HOST_WORK" 2>/dev/null || echo '?')"
  if docker ps --format '{{.Names}}' | grep -qx dev; then
    container_admin_uid="$(docker exec dev id -u admin 2>/dev/null || echo '')"
    if [[ -n "$work_uid" && -n "$container_admin_uid" && "$work_uid" != "$container_admin_uid" ]]; then
      echo "!!! work UID=${work_uid} 与容器 admin UID=${container_admin_uid} 不一致，pull 可能 Permission denied"
      echo "    修复: docker compose restart dev（entrypoint 会 chown -R）"
    fi
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
      echo "--- startup.log（最近 pull）---"
      docker exec dev grep '\[pull\]\|git 同步' /var/log/workspace-infra/startup.log 2>&1 | tail -30
    fi
  else
    echo "dev 未运行，上面 Mounts 仍可用；启动: docker compose up -d dev"
  fi
else
  echo "dev 容器不存在"
fi
echo ""
echo "========== 完 =========="
