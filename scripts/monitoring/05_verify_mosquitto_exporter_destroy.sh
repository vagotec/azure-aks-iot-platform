#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " VERIFY DESTROY - Mosquitto Exporter"
echo "============================================================"

if kubectl get deployment \
  "${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  >/dev/null 2>&1; then

  echo "ERROR: Deployment still exists."
  exit 1
fi

echo "OK: Deployment absent."

if kubectl get service \
  "${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  >/dev/null 2>&1; then

  echo "ERROR: Service still exists."
  exit 1
fi

echo "OK: Service absent."

POD_COUNT="$(
  kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=mosquitto-exporter \
    --no-headers 2>/dev/null \
    | wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
  echo "ERROR: Exporter Pods still exist."
  exit 1
fi

echo "OK: Pods absent."

echo
echo "=== Verify exporter image is absent ==="

if sudo k3s ctr -n k8s.io images list \
  | grep -F "${MOSQUITTO_EXPORTER_IMAGE}"; then

  echo "ERROR: Exporter image still exists."
  exit 1
fi

echo "OK: Exporter image absent."

echo
echo "=== Verify Phase 2 components remain healthy ==="

kubectl rollout status \
  deployment/"${MOSQUITTO_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

kubectl rollout status \
  deployment/"${ROS2_SIMULATOR_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

kubectl rollout status \
  deployment/"${BACKEND_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

echo
echo "VERIFY DESTROY PASSED"
