#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

LOCAL_PORT=19234
PF_LOG="/tmp/${PROJECT_NAME}-mosquitto-exporter-portforward.log"

cleanup()
{
  if [[ -n "${PF_PID:-}" ]]; then
    kill "${PF_PID}" 2>/dev/null || true
    wait "${PF_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

echo "============================================================"
echo " FUNCTIONAL TEST - Mosquitto Exporter"
echo "============================================================"

kubectl port-forward \
  -n "${K8S_NAMESPACE}" \
  service/"${MOSQUITTO_EXPORTER_NAME}" \
  "${LOCAL_PORT}:${MOSQUITTO_EXPORTER_PORT}" \
  >"${PF_LOG}" 2>&1 &

PF_PID=$!

sleep 3

echo
echo "=== /health ==="

HEALTH="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "http://127.0.0.1:${LOCAL_PORT}/health"
)"

echo "${HEALTH}"

grep -q '"status":"healthy"' <<< "${HEALTH}"

echo
echo "=== /metrics ==="

METRICS="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "http://127.0.0.1:${LOCAL_PORT}/metrics"
)"

printf '%s\n' "${METRICS}" \
  | grep '^broker_' \
  | head -20

echo
echo "=== Validate required broker metrics ==="

grep -q '^broker_clients_connected ' <<< "${METRICS}"
echo "OK: broker_clients_connected"

grep -q '^broker_messages_received_total ' <<< "${METRICS}"
echo "OK: broker_messages_received_total"

grep -q '^broker_messages_sent_total ' <<< "${METRICS}"
echo "OK: broker_messages_sent_total"

grep -q '^broker_bytes_received_total ' <<< "${METRICS}"
echo "OK: broker_bytes_received_total"

grep -q '^broker_bytes_sent_total ' <<< "${METRICS}"
echo "OK: broker_bytes_sent_total"

echo
echo "FUNCTIONAL TEST PASSED"
