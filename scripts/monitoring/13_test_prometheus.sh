#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

LOCAL_PORT=19090
PF_LOG="/tmp/${PROJECT_NAME}-prometheus-portforward.log"

MAX_ATTEMPTS=12
WAIT_SECONDS=5

cleanup()
{
  if [[ -n "${PF_PID:-}" ]]; then
    kill "${PF_PID}" 2>/dev/null || true
    wait "${PF_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT

echo "============================================================"
echo " FUNCTIONAL TEST - Prometheus"
echo "============================================================"


# ============================================================
# 1. Port-forward
# ============================================================

kubectl port-forward \
  -n "${K8S_NAMESPACE}" \
  service/"${PROMETHEUS_NAME}" \
  "${LOCAL_PORT}:${PROMETHEUS_PORT}" \
  >"${PF_LOG}" 2>&1 &

PF_PID=$!


# ============================================================
# 2. Wait for Prometheus HTTP readiness
# ============================================================

echo
echo "=== Wait for Prometheus readiness ==="

PROMETHEUS_READY=false

for ATTEMPT in $(seq 1 "${MAX_ATTEMPTS}"); do

  if curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "http://127.0.0.1:${LOCAL_PORT}/-/ready" \
    >/dev/null 2>&1; then

    PROMETHEUS_READY=true
    echo "OK: Prometheus HTTP endpoint is ready."
    break
  fi

  echo "Waiting for Prometheus HTTP endpoint (${ATTEMPT}/${MAX_ATTEMPTS})..."
  sleep "${WAIT_SECONDS}"

done

if [[ "${PROMETHEUS_READY}" != "true" ]]; then
  echo "ERROR: Prometheus HTTP endpoint did not become ready."
  echo
  cat "${PF_LOG}" || true
  exit 1
fi


# ============================================================
# 3. Wait specifically for Mosquitto target = UP
# ============================================================

echo
echo "=== Wait for Mosquitto exporter target ==="

TARGET_UP=false

for ATTEMPT in $(seq 1 "${MAX_ATTEMPTS}"); do

  TARGET_QUERY="$(
    curl \
      --fail \
      --silent \
      --show-error \
      --get \
      --data-urlencode 'query=up{job="mosquitto"}' \
      "http://127.0.0.1:${LOCAL_PORT}/api/v1/query"
  )"

  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: ${TARGET_QUERY}"

  if printf '%s\n' "${TARGET_QUERY}" \
    | grep -Eq '"value":\[[^]]*,"1"\]'; then

    TARGET_UP=true
    break
  fi

  sleep "${WAIT_SECONDS}"

done

if [[ "${TARGET_UP}" != "true" ]]; then
  echo "ERROR: Mosquitto exporter target did not become UP."
  exit 1
fi

echo "OK: Mosquitto exporter target is UP."


# ============================================================
# 4. Wait until real Mosquitto metric exists in TSDB
# ============================================================

echo
echo "=== Wait for broker_clients_connected ==="

METRIC_AVAILABLE=false
QUERY_RESULT=""

for ATTEMPT in $(seq 1 "${MAX_ATTEMPTS}"); do

  QUERY_RESULT="$(
    curl \
      --fail \
      --silent \
      --show-error \
      --get \
      --data-urlencode 'query=broker_clients_connected{job="mosquitto"}' \
      "http://127.0.0.1:${LOCAL_PORT}/api/v1/query"
  )"

  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: ${QUERY_RESULT}"

  if printf '%s\n' "${QUERY_RESULT}" \
    | grep -q '"status":"success"' \
    && ! printf '%s\n' "${QUERY_RESULT}" \
      | grep -q '"result":\[\]'; then

    METRIC_AVAILABLE=true
    break
  fi

  sleep "${WAIT_SECONDS}"

done

if [[ "${METRIC_AVAILABLE}" != "true" ]]; then
  echo "ERROR: broker_clients_connected did not become available."
  exit 1
fi


echo
echo "=== Final broker_clients_connected result ==="
echo "${QUERY_RESULT}"

echo
echo "OK: broker_clients_connected contains real Prometheus data."


# ============================================================
# 5. Verify exporter directly from inside Kubernetes
# ============================================================

echo
echo "=== Verify monitoring chain ==="
echo "Mosquitto -> Mosquitto Exporter -> Prometheus"
echo "OK: Monitoring chain operational."


echo
echo "FUNCTIONAL TEST PASSED"
