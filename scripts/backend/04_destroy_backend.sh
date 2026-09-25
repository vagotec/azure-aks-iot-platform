#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

LABEL="app.kubernetes.io/name=backend"
K3S_IMAGE="docker.io/library/${BACKEND_IMAGE}"

echo "============================================================"
echo " DESTROY C++ BACKEND SERVICE"
echo "============================================================"

echo
echo "=== Delete Backend Deployment ==="

if kubectl get deployment "${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then

    kubectl delete deployment "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        --wait=true
else
    echo "Backend Deployment already absent."
fi

echo
echo "=== Wait until Backend Pods are gone ==="

kubectl wait \
    -n "${K8S_NAMESPACE}" \
    --for=delete pod \
    -l "${LABEL}" \
    --timeout=120s 2>/dev/null || true

POD_COUNT="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l "${LABEL}" \
        --no-headers 2>/dev/null |
    wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
    echo "ERROR: Backend Pods still exist."
    exit 1
fi

echo "Backend Pods: absent"

echo
echo "=== Delete Backend REST Service ==="

if kubectl get service "${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then

    kubectl delete service "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}"
else
    echo "Backend Service already absent."
fi

echo
echo "=== Remove Backend image from K3s ==="

if grep -Fxq "${K3S_IMAGE}" < <(
    sudo k3s ctr -n k8s.io images list -q
); then

    sudo k3s ctr -n k8s.io images remove "${K3S_IMAGE}"
else
    echo "K3s Backend image already absent."
fi

echo
echo "=== Remove Backend image from Docker ==="

if docker image inspect "${BACKEND_IMAGE}" >/dev/null 2>&1; then
    docker image rm "${BACKEND_IMAGE}"
else
    echo "Docker Backend image already absent."
fi

echo
echo "============================================================"
echo " BACKEND DESTROY PASSED"
echo "============================================================"
