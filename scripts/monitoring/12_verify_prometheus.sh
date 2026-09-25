#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " VERIFY - Prometheus"
echo "============================================================"

kubectl rollout status \
  deployment/"${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

kubectl get deployment \
  "${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}"

kubectl get pods \
  -n "${K8S_NAMESPACE}" \
  -l app.kubernetes.io/name=prometheus \
  -o wide

kubectl get service \
  "${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  -o wide

kubectl get pvc \
  "${PROMETHEUS_PVC}" \
  -n "${K8S_NAMESPACE}"

POD="$(
  kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=prometheus \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${POD}" ]]; then
  echo "ERROR: No running Prometheus Pod found."
  exit 1
fi

READY="$(
  kubectl get pod "${POD}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.containerStatuses[0].ready}'
)"

if [[ "${READY}" != "true" ]]; then
  echo "ERROR: Prometheus Pod is not Ready."
  exit 1
fi

echo
echo "=== Prometheus logs ==="

kubectl logs \
  "${POD}" \
  -n "${K8S_NAMESPACE}" \
  --tail=30

echo
echo "VERIFY PASSED"
