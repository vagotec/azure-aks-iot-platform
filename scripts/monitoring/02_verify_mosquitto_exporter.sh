#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " VERIFY - Mosquitto Exporter"
echo "============================================================"

kubectl rollout status \
  deployment/"${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

POD="$(
  kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=mosquitto-exporter \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${POD}" ]]; then
  echo "ERROR: No running Mosquitto Exporter Pod found."
  exit 1
fi

READY="$(
  kubectl get pod "${POD}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.containerStatuses[0].ready}'
)"

if [[ "${READY}" != "true" ]]; then
  echo "ERROR: Mosquitto Exporter is not Ready."
  exit 1
fi

kubectl get pod \
  "${POD}" \
  -n "${K8S_NAMESPACE}" \
  -o wide

kubectl get service \
  "${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  -o wide

echo
echo "=== Exporter logs ==="

kubectl logs \
  "${POD}" \
  -n "${K8S_NAMESPACE}" \
  --tail=30

echo
echo "VERIFY PASSED"
