#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

ARCHIVE="/tmp/${PROJECT_NAME}-ros2-simulator.tar"

echo "========================================"
echo " Phase 2B.1 - Build ROS 2 Simulator"
echo "========================================"

command -v docker >/dev/null 2>&1 || {
    echo "ERROR: docker not found."
    exit 1
}

echo
echo "Image: ${ROS2_SIMULATOR_IMAGE}"

echo
echo "=== Docker build ==="

docker build \
    -f "${PROJECT_ROOT}/edge/ros2-simulator/container/Containerfile" \
    -t "${ROS2_SIMULATOR_IMAGE}" \
    "${PROJECT_ROOT}/edge/ros2-simulator"

echo
echo "=== Save local image ==="

rm -f "${ARCHIVE}"
docker save \
    -o "${ARCHIVE}" \
    "${ROS2_SIMULATOR_IMAGE}"

echo
echo "=== Import image into K3s containerd ==="

sudo k3s ctr -n k8s.io images import "${ARCHIVE}"

rm -f "${ARCHIVE}"

echo
echo "=== Verify K3s image ==="

sudo k3s ctr -n k8s.io images list \
    | grep -F "${ROS2_SIMULATOR_IMAGE}"

echo
echo "========================================"
echo " Phase 2B.1 completed successfully"
echo "========================================"
