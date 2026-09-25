#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "========================================"
echo " Phase 2B.3 - Verify ROS 2 Simulator"
echo "========================================"

kubectl rollout status \
    deployment/"${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=60s

READY="$(
    kubectl get deployment "${ROS2_SIMULATOR_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY:-0}" != "1" ]]; then
    echo "ERROR: ROS 2 Simulator does not have exactly one ready replica."
    exit 1
fi

POD="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=ros2-simulator \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${POD}" ]]; then
    echo "ERROR: No running ROS 2 Simulator Pod found."
    exit 1
fi

echo
echo "Running Pod: ${POD}"

echo
echo "=== Recent simulator logs ==="

kubectl logs \
    -n "${K8S_NAMESPACE}" \
    "${POD}" \
    --tail=10

echo
echo "PASSED: ROS 2 Simulator deployment is healthy."
