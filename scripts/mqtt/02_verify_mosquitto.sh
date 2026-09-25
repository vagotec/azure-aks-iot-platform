#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "========================================"
echo " Phase 2A.2 - Verify Mosquitto"
echo "========================================"

kubectl rollout status \
    deployment/"${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=60s

READY_REPLICAS="$(
    kubectl get deployment "${MOSQUITTO_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY_REPLICAS:-0}" != "1" ]]; then
    echo "ERROR: Mosquitto does not have exactly one ready replica."
    exit 1
fi

kubectl get service "${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null

kubectl get pvc "${MOSQUITTO_PVC}" \
    -n "${K8S_NAMESPACE}" >/dev/null

echo
kubectl get pods,service,pvc -n "${K8S_NAMESPACE}"

echo
echo "PASSED: Mosquitto Kubernetes resources are healthy."
