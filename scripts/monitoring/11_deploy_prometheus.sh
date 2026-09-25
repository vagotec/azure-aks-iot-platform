#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

set -a
source "${PROJECT_ROOT}/config/edge.env"
set +a

PROM_CONFIG_TEMPLATE="${PROJECT_ROOT}/monitoring/prometheus/prometheus.yml.template"
PROM_CONFIG_GENERATED="${PROJECT_ROOT}/monitoring/prometheus/prometheus.generated.yml"

K8S_TEMPLATE="${PROJECT_ROOT}/monitoring/prometheus/kubernetes/deployment.yaml.template"
K8S_GENERATED="${PROJECT_ROOT}/monitoring/prometheus/kubernetes/deployment.generated.yaml"

echo "============================================================"
echo " CREATE - Prometheus"
echo "============================================================"


echo
echo "=== Verify prerequisite: Mosquitto Exporter ==="

kubectl rollout status \
  deployment/"${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s


echo
echo "=== Verify required configuration ==="

REQUIRED_VARIABLES=(
  PROJECT_NAME
  K8S_NAMESPACE
  MOSQUITTO_EXPORTER_NAME
  MOSQUITTO_EXPORTER_PORT
  PROMETHEUS_IMAGE
  PROMETHEUS_NAME
  PROMETHEUS_CONFIGMAP
  PROMETHEUS_PVC
  PROMETHEUS_PORT
  PROMETHEUS_STORAGE_SIZE
  PROMETHEUS_SCRAPE_INTERVAL
)

for VARIABLE in "${REQUIRED_VARIABLES[@]}"; do

  if [[ -z "${!VARIABLE:-}" ]]; then
    echo "ERROR: Required variable ${VARIABLE} is empty or undefined."
    exit 1
  fi

  echo "OK: ${VARIABLE}=${!VARIABLE}"

done


echo
echo "=== Render prometheus.yml ==="

envsubst \
  '${PROMETHEUS_SCRAPE_INTERVAL} ${PROMETHEUS_PORT} ${MOSQUITTO_EXPORTER_NAME} ${K8S_NAMESPACE} ${MOSQUITTO_EXPORTER_PORT}' \
  < "${PROM_CONFIG_TEMPLATE}" \
  > "${PROM_CONFIG_GENERATED}"


if grep -n '\${[^}]*}' "${PROM_CONFIG_GENERATED}"; then
  echo "ERROR: Unresolved variables remain in prometheus.generated.yml."
  exit 1
fi


echo
echo "=== Generated Prometheus configuration ==="

cat "${PROM_CONFIG_GENERATED}"


echo
echo "=== Prepare Prometheus configuration for ConfigMap ==="

PROMETHEUS_CONFIG_INDENTED="$(
  sed 's/^/    /' "${PROM_CONFIG_GENERATED}"
)"

export PROMETHEUS_CONFIG_INDENTED


echo
echo "=== Render Kubernetes manifest ==="

envsubst \
  '${PROJECT_NAME} ${K8S_NAMESPACE} ${PROMETHEUS_CONFIGMAP} ${PROMETHEUS_PVC} ${PROMETHEUS_STORAGE_SIZE} ${PROMETHEUS_NAME} ${PROMETHEUS_IMAGE} ${PROMETHEUS_PORT} ${PROMETHEUS_CONFIG_INDENTED}' \
  < "${K8S_TEMPLATE}" \
  > "${K8S_GENERATED}"


if grep -n '\${[^}]*}' "${K8S_GENERATED}"; then
  echo "ERROR: Unresolved variables remain in Kubernetes manifest."
  exit 1
fi


echo
echo "=== Validate Kubernetes manifest ==="

kubectl apply \
  --dry-run=client \
  -f "${K8S_GENERATED}" \
  >/dev/null

echo "OK: Kubernetes manifest valid."


echo
echo "=== Deploy Prometheus ==="

kubectl apply -f "${K8S_GENERATED}"


echo
echo "=== Wait for Prometheus rollout ==="

kubectl rollout status \
  deployment/"${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=180s


echo
echo "CREATE PASSED"
