#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

set -a
source "${PROJECT_ROOT}/config/edge.env"
set +a

DATASOURCE_TEMPLATE="${PROJECT_ROOT}/monitoring/grafana/provisioning/datasources/prometheus.yml.template"
DASHBOARD_PROVIDER="${PROJECT_ROOT}/monitoring/grafana/provisioning/dashboards/dashboards.yml"
DASHBOARD="${PROJECT_ROOT}/monitoring/grafana/dashboards/iot-platform-overview.json"
MANIFEST_TEMPLATE="${PROJECT_ROOT}/monitoring/grafana/kubernetes/deployment.yaml.template"
GENERATED_MANIFEST="${PROJECT_ROOT}/monitoring/grafana/kubernetes/deployment.yaml"

echo "============================================================"
echo " CREATE - Grafana"
echo "============================================================"

echo
echo "=== Verify prerequisite: Prometheus ==="

kubectl rollout status \
  deployment/"${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

echo
echo "=== Verify required configuration ==="

REQUIRED_VARS=(
  PROJECT_NAME
  K8S_NAMESPACE
  PROMETHEUS_NAME
  PROMETHEUS_PORT
  GRAFANA_IMAGE
  GRAFANA_NAME
  GRAFANA_PROVISIONING_CONFIGMAP
  GRAFANA_PVC
  GRAFANA_PORT
  GRAFANA_STORAGE_SIZE
  GRAFANA_ADMIN_USER
  GRAFANA_ADMIN_PASSWORD
)

for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR:-}" ]]; then
    echo "ERROR: ${VAR} is not configured."
    exit 1
  fi

  if [[ "${VAR}" == "GRAFANA_ADMIN_PASSWORD" ]]; then
    echo "OK: ${VAR}=<configured>"
  else
    echo "OK: ${VAR}=${!VAR}"
  fi
done

echo
echo "=== Render Grafana datasource ==="

GRAFANA_DATASOURCE_RENDERED="$(
  envsubst \
    '${PROMETHEUS_NAME} ${K8S_NAMESPACE} ${PROMETHEUS_PORT}' \
    < "${DATASOURCE_TEMPLATE}"
)"

echo "${GRAFANA_DATASOURCE_RENDERED}"

echo
echo "=== Prepare ConfigMap content ==="

GRAFANA_DATASOURCE_CONFIG="$(
  printf '%s\n' "${GRAFANA_DATASOURCE_RENDERED}" | sed 's/^/    /'
)"

GRAFANA_DASHBOARD_PROVIDER_CONFIG="$(
  sed 's/^/    /' "${DASHBOARD_PROVIDER}"
)"

GRAFANA_DASHBOARD_CONFIG="$(
  sed 's/^/    /' "${DASHBOARD}"
)"

export GRAFANA_DATASOURCE_CONFIG
export GRAFANA_DASHBOARD_PROVIDER_CONFIG
export GRAFANA_DASHBOARD_CONFIG

echo
echo "=== Render Kubernetes manifest ==="

envsubst \
  '${PROJECT_NAME} ${K8S_NAMESPACE} ${GRAFANA_IMAGE} ${GRAFANA_NAME} ${GRAFANA_PROVISIONING_CONFIGMAP} ${GRAFANA_PVC} ${GRAFANA_PORT} ${GRAFANA_STORAGE_SIZE} ${GRAFANA_ADMIN_USER} ${GRAFANA_ADMIN_PASSWORD} ${GRAFANA_DATASOURCE_CONFIG} ${GRAFANA_DASHBOARD_PROVIDER_CONFIG} ${GRAFANA_DASHBOARD_CONFIG}' \
  < "${MANIFEST_TEMPLATE}" \
  > "${GENERATED_MANIFEST}"

if grep -Eq '\$\{[A-Z0-9_]+\}' "${GENERATED_MANIFEST}"; then
  echo "ERROR: Unresolved variables remain in generated manifest."
  grep -En '\$\{[A-Z0-9_]+\}' "${GENERATED_MANIFEST}"
  exit 1
fi

echo
echo "=== Validate Kubernetes manifest ==="

kubectl apply \
  --dry-run=client \
  -f "${GENERATED_MANIFEST}" \
  >/dev/null

echo "OK: Kubernetes manifest valid."

echo
echo "=== Deploy Grafana ==="

kubectl apply -f "${GENERATED_MANIFEST}"

echo
echo "=== Wait for Grafana rollout ==="

kubectl rollout status \
  deployment/"${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=180s

echo
echo "CREATE PASSED"
