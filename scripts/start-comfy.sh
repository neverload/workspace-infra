#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "start-comfy failed: exit=${rc} line=${LINENO} command=${BASH_COMMAND}" >&2; exit "${rc}"' ERR

COMFY_DIR="/home/admin/ref/ComfyUI"
COMFY_PORT="8188"

if [[ ! -d "${COMFY_DIR}" ]]; then
  echo "ComfyUI directory does not exist: ${COMFY_DIR}" >&2
  exit 1
fi

cd "${COMFY_DIR}"

if [[ ! -f main.py ]]; then
  echo "ComfyUI main.py does not exist: ${COMFY_DIR}/main.py" >&2
  echo "ComfyUI directory listing:" >&2
  ls -la "${COMFY_DIR}" >&2
  exit 1
fi

exec python3 main.py --listen 0.0.0.0 --port "${COMFY_PORT}"
