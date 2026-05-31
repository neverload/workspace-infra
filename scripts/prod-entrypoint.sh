#!/usr/bin/env bash
set -Eeuo pipefail

trap 'rc=$?; echo "prod-entrypoint failed: exit=${rc} line=${LINENO} command=${BASH_COMMAND}" >&2; exit "${rc}"' ERR

SSHD_PORT="2202"
LOG_DIR="/var/log/workspace-infra"
COMFY_LOG="${LOG_DIR}/comfy.log"
SSHD_LOG="${LOG_DIR}/prod-sshd.log"

mkdir -p "${LOG_DIR}"

terminate_children() {
  local rc="$1"
  if [[ -n "${sshd_pid:-}" ]] && kill -0 "${sshd_pid}" 2>/dev/null; then
    kill "${sshd_pid}" 2>/dev/null || true
  fi
  if [[ -n "${comfy_pid:-}" ]] && kill -0 "${comfy_pid}" 2>/dev/null; then
    kill "${comfy_pid}" 2>/dev/null || true
  fi
  exit "${rc}"
}

trap 'terminate_children 143' TERM INT

/bin/bash /usr/local/bin/workspace-infra-entrypoint.sh "${SSHD_PORT}" >"${SSHD_LOG}" 2>&1 &
sshd_pid="$!"

/bin/bash /usr/local/bin/start-comfy >"${COMFY_LOG}" 2>&1 &
comfy_pid="$!"

echo "prod-entrypoint started: sshd_pid=${sshd_pid} comfy_pid=${comfy_pid}" >&2

rc="0"
while true; do
  if ! kill -0 "${sshd_pid}" 2>/dev/null; then
    wait "${sshd_pid}" || rc="$?"
    break
  fi
  if ! kill -0 "${comfy_pid}" 2>/dev/null; then
    wait "${comfy_pid}" || rc="$?"
    break
  fi
  sleep 1
done

echo "prod-entrypoint child exited: exit=${rc}" >&2
echo "---- sshd log tail ----" >&2
tail -100 "${SSHD_LOG}" >&2 || true
echo "---- comfy log tail ----" >&2
tail -100 "${COMFY_LOG}" >&2 || true

terminate_children "${rc}"
