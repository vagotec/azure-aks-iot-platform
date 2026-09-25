#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Export all variables loaded from edge.env so envsubst can see them.
set -a
source "${PROJECT_ROOT}/config/edge.env"
set +a

TEMPLATE="${PROJECT_ROOT}/monitoring/mosquitto-exporter/kubernetes/deployment.yaml.template"
RENDERED="${PROJECT_ROOT}/monitoring/mosquitto-exporter/kubernetes/deployment.generated.yaml"

echo "============================================================"
echo " CREATE - Mosquitto Exporter"
echo "============================================================"

echo
echo "=== Verify prerequisite: Mosquitto ==="

kubectl rollout status \
  deployment/"${MOSQUITTO_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s


echo
echo "=== Verify required configuration ==="

REQUIRED_VARIABLES=(
  PROJECT_NAME
  K8S_NAMESPACE
  MOSQUITTO_NAME
  MQTT_PORT
  MOSQUITTO_EXPORTER_IMAGE
  MOSQUITTO_EXPORTER_NAME
  MOSQUITTO_EXPORTER_PORT
)

for VARIABLE in "${REQUIRED_VARIABLES[@]}"; do

  if [[ -z "${!VARIABLE:-}" ]]; then
    echo "ERROR: Required variable ${VARIABLE} is empty or undefined."
    exit 1
  fi

  echo "OK: ${VARIABLE}=${!VARIABLE}"

done


echo
echo "=== Render Kubernetes manifest ==="

envsubst \
  '${PROJECT_NAME} ${K8S_NAMESPACE} ${MOSQUITTO_NAME} ${MQTT_PORT} ${MOSQUITTO_EXPORTER_IMAGE} ${MOSQUITTO_EXPORTER_NAME} ${MOSQUITTO_EXPORTER_PORT}' \
  < "${TEMPLATE}" \
  > "${RENDERED}"


echo
echo "=== Verify rendered manifest contains no placeholders ==="

if grep -n '\${[^}]*}' "${RENDERED}"; then
  echo
  echo "ERROR: Unresolved variables remain in generated manifest."
  exit 1
fi

echo "OK: No unresolved variables."


echo
echo "=== Validate Kubernetes manifest locally ==="

kubectl apply \
  --dry-run=client \
  -f "${RENDERED}" \
  >/dev/null

echo "OK: Kubernetes manifest syntax valid."


echo
echo "=== Rendered resource names ==="

grep -E '^[[:space:]]*name:' "${RENDERED}"


echo
echo "=== Deploy Mosquitto Exporter ==="

kubectl apply -f "${RENDERED}"


echo
echo "=== Wait for Mosquitto Exporter rollout ==="

kubectl rollout status \
  deployment/"${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s


echo
echo "CREATE PASSED"
