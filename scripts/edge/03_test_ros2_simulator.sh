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

echo "Pod:             ${POD}"
echo "Telemetry topic: ${ROS2_TOPIC}"
echo "Command service: ${ROS2_COMMAND_SERVICE}"
echo "Domain:          ${ROS_DOMAIN_ID}"
echo "Device:          ${DEVICE_ID}"

echo
echo "=== TEST 1/2 - Receive ROS 2 telemetry ==="

MESSAGE="$(
    kubectl exec \
        -n "${K8S_NAMESPACE}" \
        "${POD}" -- \
        bash -lc "
          source /opt/ros/jazzy/setup.bash
          source /workspace/install/setup.bash
          export ROS_DOMAIN_ID='${ROS_DOMAIN_ID}'
          timeout 15 ros2 topic echo \
            '${ROS2_TOPIC}' \
            std_msgs/msg/String \
            --once
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
echo "PASSED: ROS 2 telemetry received."

echo
echo "=== TEST 2/2 - Device command service round-trip ==="

echo
echo "--- Available ROS 2 services ---"

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${POD}" -- \
    bash -lc "
      source /opt/ros/jazzy/setup.bash
      source /workspace/install/setup.bash
      export ROS_DOMAIN_ID='${ROS_DOMAIN_ID}'
      ros2 service list -t
    "

echo
echo "--- Call simulator command service ---"

SERVICE_RESPONSE="$(
    kubectl exec \
        -n "${K8S_NAMESPACE}" \
        "${POD}" -- \
        bash -lc "
          source /opt/ros/jazzy/setup.bash
          source /workspace/install/setup.bash
          export ROS_DOMAIN_ID='${ROS_DOMAIN_ID}'
          timeout 15 ros2 service call \
            '${ROS2_COMMAND_SERVICE}' \
            vagotec_iot_interfaces/srv/DeviceCommand \
            \"{command: test, value: hello}\"
        "
)"

echo "${SERVICE_RESPONSE}"

if ! grep -Fq "success=True" <<< "${SERVICE_RESPONSE}"; then
    echo "FAILED: Simulator did not return success=True."
    exit 1
fi

if ! grep -Fq "status='executed'" <<< "${SERVICE_RESPONSE}"; then
    echo "FAILED: Simulator did not return status=executed."
    exit 1
fi

if ! grep -Fq \
    "Simulator executed command 'test' with value 'hello'" \
    <<< "${SERVICE_RESPONSE}"; then

    echo "FAILED: Expected simulator response message not found."
    exit 1
fi

echo
echo "PASSED: ROS 2 command was executed and acknowledged by simulator."

echo
echo "========================================"
echo " ROS 2 SIMULATOR FUNCTIONAL TEST PASSED"
echo " Telemetry topic       : PASSED"
echo " Command service       : PASSED"
echo " Device acknowledgement: PASSED"
echo "========================================"
