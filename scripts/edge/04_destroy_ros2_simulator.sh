#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

RENDERED="${PROJECT_ROOT}/edge/ros2-simulator/kubernetes/deployment.generated.yaml"
K3S_IMAGE_REF="docker.io/library/${ROS2_SIMULATOR_IMAGE}"

echo "========================================"
echo " Phase 2B.5 - Destroy ROS 2 Simulator"
echo "========================================"

echo
echo "Deployment: ${ROS2_SIMULATOR_NAME}"
echo "Namespace:  ${K8S_NAMESPACE}"
echo "Image:      ${ROS2_SIMULATOR_IMAGE}"

echo
echo "=== Delete Kubernetes Deployment ==="

kubectl delete deployment "${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --ignore-not-found=true

echo
echo "=== Wait until simulator Pods are completely deleted ==="

if ! kubectl wait \
    --for=delete pod \
    -l app.kubernetes.io/name=ros2-simulator \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s; then

    echo "ERROR: Simulator Pod deletion timed out."
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=ros2-simulator \
        -o wide || true
    exit 1
fi

POD_COUNT="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=ros2-simulator \
        --no-headers 2>/dev/null |
        wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
    echo "ERROR: Simulator Pods still exist."
    exit 1
fi

echo "OK: Simulator Pods completely removed."

echo
echo "=== Remove generated manifest ==="

rm -f "${RENDERED}"

echo
echo "=== Remove simulator image from K3s containerd ==="

if grep -Fxq "${K3S_IMAGE_REF}" < <(
    sudo k3s ctr -n k8s.io images list -q
); then

    sudo k3s ctr -n k8s.io images remove "${K3S_IMAGE_REF}"
    echo "Removed from K3s: ${K3S_IMAGE_REF}"
else
    echo "K3s image already absent: ${K3S_IMAGE_REF}"
fi

echo
echo "=== Remove simulator image from Docker ==="

if docker image inspect "${ROS2_SIMULATOR_IMAGE}" >/dev/null 2>&1; then
    docker image rm "${ROS2_SIMULATOR_IMAGE}"
    echo "Removed from Docker: ${ROS2_SIMULATOR_IMAGE}"
else
    echo "Docker image already absent: ${ROS2_SIMULATOR_IMAGE}"
fi

echo
echo "========================================"
echo " Phase 2B.5 destroy completed"
echo "========================================"
