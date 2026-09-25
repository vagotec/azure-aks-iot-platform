#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/config/edge.env"
TEMPLATE="${PROJECT_ROOT}/edge/ros2-simulator/kubernetes/deployment.yaml.template"
RENDERED="${PROJECT_ROOT}/edge/ros2-simulator/kubernetes/deployment.generated.yaml"

set -a
source "${ENV_FILE}"
set +a

ARCHIVE="/tmp/${PROJECT_NAME}-ros2-simulator.tar"

echo "============================================================"
echo " DEPLOY - ROS 2 Simulator"
echo "============================================================"

echo
echo "=== Verify prerequisites ==="

command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker not found."
    exit 1
}

command -v kubectl >/dev/null 2>&1 || {
    echo "ERROR: kubectl not found."
    exit 1
}

command -v envsubst >/dev/null 2>&1 || {
    echo "ERROR: envsubst not found."
    exit 1
}

kubectl get namespace "${K8S_NAMESPACE}" >/dev/null

echo
echo "Image:      ${ROS2_SIMULATOR_IMAGE}"
echo "Deployment: ${ROS2_SIMULATOR_NAME}"
echo "Namespace:  ${K8S_NAMESPACE}"

echo
echo "=== Build ROS 2 Simulator image ==="

docker build \
    -f "${PROJECT_ROOT}/edge/ros2-simulator/container/Containerfile" \
    -t "${ROS2_SIMULATOR_IMAGE}" \
    "${PROJECT_ROOT}"

echo
echo "=== Export simulator image ==="

rm -f "${ARCHIVE}"

docker save \
    -o "${ARCHIVE}" \
    "${ROS2_SIMULATOR_IMAGE}"

echo
echo "=== Import simulator image into K3s containerd ==="

sudo k3s ctr -n k8s.io images import "${ARCHIVE}"

rm -f "${ARCHIVE}"

echo
echo "=== Verify imported K3s image ==="

K3S_IMAGE_REF="docker.io/library/${ROS2_SIMULATOR_IMAGE}"

sudo k3s ctr -n k8s.io images list -q \
    | grep -Fx "${K3S_IMAGE_REF}"

echo
echo "=== Render Kubernetes manifest ==="

envsubst < "${TEMPLATE}" > "${RENDERED}"

echo
echo "=== Validate Kubernetes manifest ==="

kubectl apply \
    --dry-run=server \
    -f "${RENDERED}"

echo
echo "=== Deploy ROS 2 Simulator ==="

kubectl apply -f "${RENDERED}"

echo
echo "=== Wait for simulator rollout ==="

kubectl rollout status \
    deployment/"${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s

echo
echo "=== Simulator Pod ==="

kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=ros2-simulator \
    -o wide

echo
echo "============================================================"
echo " ROS 2 SIMULATOR DEPLOY PASSED"
echo "============================================================"
