#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " VERIFY DESTROY - Prometheus"
echo "============================================================"

for RESOURCE in \
  "deployment/${PROMETHEUS_NAME}" \
  "service/${PROMETHEUS_NAME}" \
  "configmap/${PROMETHEUS_CONFIGMAP}" \
  "pvc/${PROMETHEUS_PVC}"
do

  if kubectl get "${RESOURCE}" \
    -n "${K8S_NAMESPACE}" \
    >/dev/null 2>&1; then

    echo "ERROR: ${RESOURCE} still exists."
    exit 1
  fi

  echo "OK: ${RESOURCE} absent."

done


POD_COUNT="$(
  kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=prometheus \
    --no-headers 2>/dev/null \
    | wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
  echo "ERROR: Prometheus Pods still exist."
  exit 1
fi

echo "OK: Prometheus Pods absent."


echo
echo "=== Verify Prometheus image is absent ==="

if grep -Fq "${PROMETHEUS_IMAGE}" < <(
  sudo k3s ctr -n k8s.io images list
); then

  echo "ERROR: Prometheus image still exists."
  exit 1
fi

echo "OK: Prometheus image absent."


echo
echo "=== Verify existing platform components remain healthy ==="

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

kubectl rollout status \
  deployment/"${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

echo
echo "VERIFY DESTROY PASSED"
