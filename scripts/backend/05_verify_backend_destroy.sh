#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

FAILED=0
LABEL="app.kubernetes.io/name=backend"
K3S_IMAGE="docker.io/library/${BACKEND_IMAGE}"

echo "============================================================"
echo " VERIFY BACKEND DESTROY"
echo "============================================================"

if kubectl get deployment "${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Backend Deployment still exists."
    FAILED=1
else
    echo "OK: Backend Deployment absent."
fi

POD_COUNT="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l "${LABEL}" \
        --no-headers 2>/dev/null |
    wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
    echo "ERROR: Backend Pods still exist."
    FAILED=1
else
    echo "OK: Backend Pods absent."
fi

if kubectl get service "${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Backend REST Service still exists."
    FAILED=1
else
    echo "OK: Backend REST Service absent."
fi

if sudo k3s ctr -n k8s.io images list -q |
    grep -Fxq "${K3S_IMAGE}"; then
    echo "ERROR: Backend image still exists in K3s."
    FAILED=1
else
    echo "OK: Backend image absent from K3s."
fi

if docker image inspect "${BACKEND_IMAGE}" >/dev/null 2>&1; then
    echo "ERROR: Backend image still exists in Docker."
    FAILED=1
else
    echo "OK: Backend image absent from Docker."
fi

echo
echo "=== Verify previous components remain operational ==="

kubectl rollout status \
    deployment/"${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=60s

kubectl rollout status \
    deployment/"${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=60s

if [[ "${FAILED}" -ne 0 ]]; then
    echo
    echo "BACKEND DESTROY VERIFICATION FAILED"
    exit 1
fi

echo
echo "============================================================"
echo " BACKEND DESTROY VERIFICATION PASSED"
echo "============================================================"
