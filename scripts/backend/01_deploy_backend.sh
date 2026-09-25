#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/config/edge.env"
DEPLOYMENT_TEMPLATE="${PROJECT_ROOT}/services/backend/kubernetes/deployment.yaml.template"
DEPLOYMENT_RENDERED="${PROJECT_ROOT}/services/backend/kubernetes/deployment.generated.yaml"
SERVICE_TEMPLATE="${PROJECT_ROOT}/services/backend/kubernetes/service.yaml.template"
SERVICE_RENDERED="${PROJECT_ROOT}/services/backend/kubernetes/service.generated.yaml"

set -a
source "${ENV_FILE}"
set +a

ARCHIVE="/tmp/${PROJECT_NAME}-backend.tar"

cleanup() {
    rm -f "${ARCHIVE}"
}
trap cleanup EXIT

echo "============================================================"
echo " DEPLOY C++ BACKEND SERVICE"
echo "============================================================"

echo
echo "=== Verify prerequisites ==="

kubectl get namespace "${K8S_NAMESPACE}" >/dev/null

kubectl rollout status \
    deployment/"${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=60s

kubectl rollout status \
    deployment/"${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=60s

echo
echo "=== Build Backend image ==="

# The Backend depends on the shared ROS 2 interface package.
# Therefore the project root is the Docker build context.
docker build \
    -f "${PROJECT_ROOT}/services/backend/container/Containerfile" \
    -t "${BACKEND_IMAGE}" \
    "${PROJECT_ROOT}"

echo
echo "=== Import Backend image into K3s ==="

docker save \
    -o "${ARCHIVE}" \
    "${BACKEND_IMAGE}"

sudo k3s ctr -n k8s.io images import "${ARCHIVE}"

K3S_IMAGE="docker.io/library/${BACKEND_IMAGE}"

grep -Fxq "${K3S_IMAGE}" < <(
    sudo k3s ctr -n k8s.io images list -q
)

echo "K3s image: ${K3S_IMAGE}"

echo
echo "=== Render Kubernetes manifests ==="

envsubst < "${DEPLOYMENT_TEMPLATE}" > "${DEPLOYMENT_RENDERED}"
envsubst < "${SERVICE_TEMPLATE}" > "${SERVICE_RENDERED}"

kubectl apply --dry-run=client \
    -f "${SERVICE_RENDERED}" >/dev/null

kubectl apply --dry-run=client \
    -f "${DEPLOYMENT_RENDERED}" >/dev/null

echo
echo "=== Stop existing Backend Pod if present ==="

if kubectl get deployment "${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then

    kubectl scale deployment/"${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        --replicas=0

    kubectl wait \
        -n "${K8S_NAMESPACE}" \
        --for=delete pod \
        -l app.kubernetes.io/name=backend \
        --timeout=120s
else
    echo "Backend Deployment not present. Fresh deployment."
fi

echo
echo "=== Deploy Backend Service and Deployment ==="

kubectl apply -f "${SERVICE_RENDERED}"
kubectl apply -f "${DEPLOYMENT_RENDERED}"

kubectl rollout status \
    deployment/"${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s

echo
kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=backend \
    -o wide

echo
echo "============================================================"
echo " BACKEND DEPLOY PASSED"
echo "============================================================"
