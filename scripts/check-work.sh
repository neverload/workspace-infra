#!/bin/bash
# 宿主机执行：./scripts/check-work.sh
set -euo pipefail

VOLUME_NAME="${WORK_VOLUME:-workspace_infra_work_data}"

echo "=== 卷 ${VOLUME_NAME} ==="
if docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
  MP="$(docker volume inspect "$VOLUME_NAME" --format '{{.Mountpoint}}')"
  echo "Mountpoint: ${MP}"
  sudo ls -la "$MP" 2>/dev/null || echo "(无权限 ls，用 sudo)"
else
  echo "卷不存在"
fi

echo ""
echo "=== 容器 dev ==="
if docker ps --format '{{.Names}}' | grep -qx dev; then
  docker exec dev ls -la /home/admin/work 2>/dev/null || echo "exec 失败"
else
  echo "dev 未运行"
fi

echo ""
echo "说明：代码在卷里 → 容器 /home/admin/work；宿主机 ~/work 与此无关。"
