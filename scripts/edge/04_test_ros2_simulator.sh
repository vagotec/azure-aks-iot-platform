#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "========================================"
echo " Phase 2B.4 - ROS 2 Functional Test"
echo "========================================"

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

echo "Pod:      ${POD}"
echo "Topic:    ${ROS2_TOPIC}"
echo "Domain:   ${ROS_DOMAIN_ID}"
echo "Device:   ${DEVICE_ID}"

echo
echo "=== ROS 2 topic list ==="

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${POD}" -- \
    bash -lc "
      source /opt/ros/jazzy/setup.bash
      source /workspace/install/setup.bash
      ros2 topic list
    "

echo
echo "=== Receive one telemetry message ==="

MESSAGE="$(
    kubectl exec \
        -n "${K8S_NAMESPACE}" \
        "${POD}" -- \
        bash -lc "
          source /opt/ros/jazzy/setup.bash
          source /workspace/install/setup.bash
          timeout 15 ros2 topic echo '${ROS2_TOPIC}' std_msgs/msg/String --once
        "
)"

echo "${MESSAGE}"

if ! grep -Fq "\"device_id\":\"${DEVICE_ID}\"" <<< "${MESSAGE}"; then
    echo "FAILED: Expected device_id not found."
    exit 1
fi

if ! grep -Fq '"temperature_c":' <<< "${MESSAGE}"; then
    echo "FAILED: temperature_c not found."
    exit 1
fi

if ! grep -Fq '"humidity_percent":' <<< "${MESSAGE}"; then
    echo "FAILED: humidity_percent not found."
    exit 1
fi

echo
echo "PASSED: ROS 2 telemetry received successfully."
