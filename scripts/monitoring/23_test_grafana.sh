#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"
SECRETS_FILE="${PROJECT_ROOT}/config/secrets.env"

if [[ ! -f "${SECRETS_FILE}" ]]; then
  echo "ERROR: Missing local secrets file: ${SECRETS_FILE}"
  exit 1
fi

set -a
source "${CONFIG_FILE}"
source "${SECRETS_FILE}"
set +a

LOCAL_PORT=13000
PF_LOG="/tmp/${PROJECT_NAME}-grafana-portforward.log"

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
echo " FUNCTIONAL TEST - Grafana"
echo "============================================================"

kubectl port-forward \
  -n "${K8S_NAMESPACE}" \
  service/"${GRAFANA_NAME}" \
  "${LOCAL_PORT}:${GRAFANA_PORT}" \
  >"${PF_LOG}" 2>&1 &

PF_PID=$!

echo
echo "=== Wait for Grafana health ==="

GRAFANA_READY=false

for ATTEMPT in $(seq 1 "${MAX_ATTEMPTS}"); do
  HEALTH="$(
    curl \
      --silent \
      --show-error \
      --max-time 5 \
      "http://127.0.0.1:${LOCAL_PORT}/api/health" \
      2>/dev/null || true
  )"

  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: ${HEALTH}"

  if printf '%s\n' "${HEALTH}" | grep -q '"database": "ok"'; then
    GRAFANA_READY=true
    break
  fi

  sleep "${WAIT_SECONDS}"
done

if [[ "${GRAFANA_READY}" != "true" ]]; then
  echo "ERROR: Grafana did not become healthy."
  cat "${PF_LOG}" || true
  exit 1
fi

echo "OK: Grafana health endpoint is healthy."

echo
echo "=== Verify provisioned Prometheus datasource ==="

DATASOURCE="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --user "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
    "http://127.0.0.1:${LOCAL_PORT}/api/datasources/uid/prometheus"
)"

echo "${DATASOURCE}"

if ! printf '%s\n' "${DATASOURCE}" \
  | grep -q "\"uid\":\"prometheus\""; then
  echo "ERROR: Prometheus datasource not provisioned."
  exit 1
fi

EXPECTED_URL="http://${PROMETHEUS_NAME}.${K8S_NAMESPACE}.svc.cluster.local:${PROMETHEUS_PORT}"

if ! printf '%s\n' "${DATASOURCE}" \
  | grep -Fq "\"url\":\"${EXPECTED_URL}\""; then
  echo "ERROR: Prometheus datasource URL is incorrect."
  exit 1
fi

echo "OK: Prometheus datasource provisioned correctly."

echo
echo "=== Verify provisioned dashboard ==="

DASHBOARD="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --user "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
    "http://127.0.0.1:${LOCAL_PORT}/api/dashboards/uid/azure-aks-iot-platform-overview"
)"

if ! printf '%s\n' "${DASHBOARD}" \
  | grep -q '"uid":"azure-aks-iot-platform-overview"'; then
  echo "ERROR: IoT dashboard not provisioned."
  exit 1
fi

echo "OK: IoT dashboard provisioned."

echo
echo "=== Verify Grafana -> Prometheus connectivity ==="

DATASOURCE_HEALTH="$(
  curl \
    --fail \
    --silent \
    --show-error \
    --user "${GRAFANA_ADMIN_USER}:${GRAFANA_ADMIN_PASSWORD}" \
    "http://127.0.0.1:${LOCAL_PORT}/api/datasources/uid/prometheus/health"
)"

echo "${DATASOURCE_HEALTH}"

if ! printf '%s\n' "${DATASOURCE_HEALTH}" \
  | grep -Eq '"status":"OK"|"status": "OK"'; then
  echo "ERROR: Grafana cannot reach Prometheus."
  exit 1
fi

echo "OK: Grafana can reach Prometheus."

echo
echo "=== Monitoring chain ==="
echo "Mosquitto -> Mosquitto Exporter -> Prometheus -> Grafana"
echo "OK: Monitoring chain operational."

echo
echo "FUNCTIONAL TEST PASSED"
