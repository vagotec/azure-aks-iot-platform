#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " VERIFY - Grafana"
echo "============================================================"

kubectl rollout status \
  deployment/"${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

kubectl get deployment \
  "${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  -o wide

kubectl get pods \
  -n "${K8S_NAMESPACE}" \
  -l app.kubernetes.io/name=grafana \
  -o wide

kubectl get service \
  "${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  -o wide

kubectl get pvc \
  "${GRAFANA_PVC}" \
  -n "${K8S_NAMESPACE}"

echo
echo "=== Grafana logs ==="

kubectl logs \
  deployment/"${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --tail=50

echo
echo "VERIFY PASSED"
