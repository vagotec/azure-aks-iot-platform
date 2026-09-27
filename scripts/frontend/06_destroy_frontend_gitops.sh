#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

echo "============================================================"
echo " DESTROY - React Frontend (GitOps lifecycle)"
echo "============================================================"

echo
echo "=== Preserve GitOps-owned HTTPRoute ==="

if kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "OK: HTTPRoute ${HTTPROUTE_NAME} is preserved."
else
    echo "WARNING: HTTPRoute ${HTTPROUTE_NAME} is already absent."
fi

echo
echo "=== Delete Frontend Deployment ==="

kubectl delete deployment "${FRONTEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --ignore-not-found=true

echo
echo "=== Delete Frontend Service ==="

kubectl delete service "${FRONTEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --ignore-not-found=true

echo
echo "=== Wait until Frontend Pods are completely gone ==="

while kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=frontend \
    --no-headers 2>/dev/null | grep -q .; do
    echo "Waiting for Frontend Pod deletion..."
    sleep 2
done

echo "OK: Frontend Pods removed."

echo
echo "=== Remove Frontend image from K3s/containerd ==="

K3S_IMAGE="docker.io/library/${FRONTEND_IMAGE}"

if grep -Fq "${K3S_IMAGE}" < <(
    sudo k3s ctr -n k8s.io images list
); then
    sudo k3s ctr -n k8s.io images rm "${K3S_IMAGE}"
else
    echo "K3s Frontend image already absent."
fi

echo
echo "=== Remove Frontend image from Docker ==="

if docker image inspect "${FRONTEND_IMAGE}" >/dev/null 2>&1; then
    docker image rm "${FRONTEND_IMAGE}"
else
    echo "Docker Frontend image already absent."
fi

echo
echo "============================================================"
echo " FRONTEND GITOPS DESTROY PASSED"
echo "============================================================"
