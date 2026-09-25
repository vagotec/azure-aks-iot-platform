#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " VERIFY DESTROY - Grafana"
echo "============================================================"

check_absent()
{
  local RESOURCE_TYPE="$1"
  local RESOURCE_NAME="$2"

  if kubectl get \
    "${RESOURCE_TYPE}" \
    "${RESOURCE_NAME}" \
    -n "${K8S_NAMESPACE}" \
    >/dev/null 2>&1; then

    echo "ERROR: ${RESOURCE_TYPE}/${RESOURCE_NAME} still exists."
    exit 1
  fi

  echo "OK: ${RESOURCE_TYPE}/${RESOURCE_NAME} absent."
}

check_absent deployment "${GRAFANA_NAME}"
check_absent service "${GRAFANA_NAME}"
check_absent configmap "${GRAFANA_PROVISIONING_CONFIGMAP}"
check_absent secret "${GRAFANA_SECRET}"
check_absent pvc "${GRAFANA_PVC}"

if kubectl get pods \
  -n "${K8S_NAMESPACE}" \
  -l app.kubernetes.io/name=grafana \
  --no-headers 2>/dev/null \
  | grep -q .; then

  echo "ERROR: Grafana Pods still exist."
  exit 1
fi

echo "OK: Grafana Pods absent."

echo
echo "=== Verify Grafana image is absent ==="

CANONICAL_IMAGE="${GRAFANA_IMAGE}"

if [[ "${CANONICAL_IMAGE}" != */*/* ]]; then
  CANONICAL_IMAGE="docker.io/${CANONICAL_IMAGE}"
fi

if grep -Fxq "${CANONICAL_IMAGE}" < <(
  sudo k3s ctr -n k8s.io images list |
    awk '{print $1}'
); then

  echo "ERROR: Grafana image still exists."
  exit 1
fi

echo "OK: Grafana image absent."

echo
echo "=== Verify existing monitoring/platform components remain healthy ==="

kubectl rollout status \
  deployment/"${MOSQUITTO_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

kubectl rollout status \
  deployment/"${ROS2_SIMULATOR_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

kubectl rollout status \
  deployment/"${BACKEND_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

kubectl rollout status \
  deployment/"${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

kubectl rollout status \
  deployment/"${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

echo
echo "VERIFY DESTROY PASSED"
