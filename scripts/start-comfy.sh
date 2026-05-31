#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "start-comfy failed: exit=${rc} line=${LINENO} command=${BASH_COMMAND}" >&2; exit "${rc}"' ERR

COMFY_DIR="/workspace/ComfyUI"
COMFY_PORT="8188"

if [[ ! -d "${COMFY_DIR}" ]]; then
  echo "ComfyUI directory does not exist: ${COMFY_DIR}" >&2
  exit 1
fi

cd "${COMFY_DIR}"
exec python3 main.py --listen 0.0.0.0 --port "${COMFY_PORT}"
