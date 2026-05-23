#!/usr/bin/env bash
set -euo pipefail

NGROK_API="${NGROK_API:-http://127.0.0.1:4040}"
NGROK_SYSTEMD_UNIT="${NGROK_SYSTEMD_UNIT:-ngrok-dev-ssh.service}"

main() {
  local json

  if systemctl is-active --quiet "${NGROK_SYSTEMD_UNIT}"; then
    echo "systemd: ${NGROK_SYSTEMD_UNIT} 运行中"
  else
    echo "systemd: ${NGROK_SYSTEMD_UNIT} 未运行"
  fi
  echo ""

  if ! json="$(curl -sf --max-time 5 "${NGROK_API}/api/tunnels")"; then
    echo "错误: 无法访问 ngrok API ${NGROK_API}" >&2
    echo "请检查 ngrok 进程是否在运行" >&2
    exit 1
  fi

  NGROK_JSON="${json}" python3 - <<'PY'
import json
import os
import sys
import urllib.parse

raw = os.environ.get("NGROK_JSON", "")
try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    print(f"错误: ngrok API 返回非法 JSON: {exc}", file=sys.stderr)
    sys.exit(1)

tunnels = data.get("tunnels")
if not tunnels:
    print("无活动隧道")
    sys.exit(0)

print("隧道列表:")
print("=" * 60)
for tunnel in tunnels:
    name = tunnel.get("name", "(未命名)")
    public_url = tunnel.get("public_url", "")
    proto = tunnel.get("proto", "")
    config = tunnel.get("config") or {}
    addr = config.get("addr", "")

    host = ""
    port = ""
    if public_url:
        parsed = urllib.parse.urlparse(public_url)
        host = parsed.hostname or ""
        port = parsed.port or ""

    print(f"名称:       {name}")
    print(f"协议:       {proto}")
    print(f"公网 URL:   {public_url}")
    print(f"本地转发:   {addr}")
    if host and port:
        print(f"SSH 示例:   ssh -p {port} admin@{host}")
    print("-" * 60)
PY
}

main "$@"
