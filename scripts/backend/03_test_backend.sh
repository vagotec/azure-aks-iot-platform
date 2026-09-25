#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

HEALTH_PORT=18080
TELEMETRY_PORT=18081
COMMAND_PORT=18082

PF_PID=""
SUBSCRIBER_PID=""
TMP_FILES=()

cleanup() {
    if [[ -n "${SUBSCRIBER_PID}" ]]; then
        kill "${SUBSCRIBER_PID}" 2>/dev/null || true
        wait "${SUBSCRIBER_PID}" 2>/dev/null || true
    fi

    if [[ -n "${PF_PID}" ]]; then
        kill "${PF_PID}" 2>/dev/null || true
        wait "${PF_PID}" 2>/dev/null || true
    fi

    for file in "${TMP_FILES[@]}"; do
        rm -f "${file}"
    done
}
trap cleanup EXIT

new_tmp() {
    local file
    file="$(mktemp)"
    TMP_FILES+=("${file}")
    printf '%s\n' "${file}"
}

stop_port_forward() {
    if [[ -n "${PF_PID}" ]]; then
        kill "${PF_PID}" 2>/dev/null || true
        wait "${PF_PID}" 2>/dev/null || true
        PF_PID=""
    fi
}

start_port_forward() {
    local local_port="$1"
    local log_file="$2"

    kubectl port-forward \
        -n "${K8S_NAMESPACE}" \
        service/"${BACKEND_NAME}" \
        "${local_port}:${REST_PORT}" \
        >"${log_file}" 2>&1 &

    PF_PID=$!

    for _ in $(seq 1 30); do
        if curl \
            --silent \
            --fail \
            --http1.1 \
            "http://127.0.0.1:${local_port}/api/health" \
            >/dev/null 2>&1; then
            return 0
        fi

        if ! kill -0 "${PF_PID}" 2>/dev/null; then
            echo "ERROR: kubectl port-forward terminated."
            cat "${log_file}"
            return 1
        fi

        sleep 0.2
    done

    echo "ERROR: REST API did not become reachable."
    cat "${log_file}"
    return 1
}

echo "============================================================"
echo " BACKEND FUNCTIONAL TEST"
echo "============================================================"

kubectl rollout status \
    deployment/"${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s

BACKEND_POD="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=backend \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}'
)"

MOSQUITTO_POD="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=mosquitto \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}'
)"

SIMULATOR_POD="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=ros2-simulator \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${BACKEND_POD}" ||
      -z "${MOSQUITTO_POD}" ||
      -z "${SIMULATOR_POD}" ]]; then
    echo "ERROR: Required Pods not found."
    exit 1
fi


# ------------------------------------------------------------
# TEST 1 - ROS 2 -> Backend -> MQTT 5
# ------------------------------------------------------------

echo
echo "=== 1/5 ROS 2 -> C++ Backend -> MQTT 5 ==="

MESSAGE="$(
    kubectl exec \
        -n "${K8S_NAMESPACE}" \
        "${MOSQUITTO_POD}" -- \
        timeout 20 mosquitto_sub \
            -V mqttv5 \
            -h localhost \
            -p "${MQTT_PORT}" \
            -t "${MQTT_TOPIC}" \
            -q "${MQTT_QOS}" \
            -C 1
)"

python3 - "${MESSAGE}" "${DEVICE_ID}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])

if data.get("device_id") != sys.argv[2]:
    raise SystemExit("ERROR: Unexpected telemetry device_id.")

for field in ("temperature_c", "humidity_percent"):
    if not isinstance(data.get(field), (int, float)):
        raise SystemExit(f"ERROR: Invalid telemetry field: {field}")

print("Telemetry payload: VALID")
PY

echo "PASSED: ROS 2 -> MQTT 5"


# ------------------------------------------------------------
# TEST 2 - MQTT 5 -> Backend -> ROS 2
# ------------------------------------------------------------

echo
echo "=== 2/5 MQTT 5 -> C++ Backend -> ROS 2 ==="

MQTT_COMMAND='{"command":"test","value":"backend-mqtt"}'
MQTT_ROS_OUTPUT="$(new_tmp)"

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${SIMULATOR_POD}" -- \
    bash -lc "
        source /opt/ros/jazzy/setup.bash
        source /workspace/install/setup.bash
        export ROS_DOMAIN_ID='${ROS_DOMAIN_ID}'
        timeout 20 ros2 topic echo \
            '${ROS2_COMMAND_TOPIC}' \
            std_msgs/msg/String \
            --once
    " >"${MQTT_ROS_OUTPUT}" 2>&1 &

SUBSCRIBER_PID=$!

sleep 3

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${MOSQUITTO_POD}" -- \
    mosquitto_pub \
        -V mqttv5 \
        -h localhost \
        -p "${MQTT_PORT}" \
        -t "${MQTT_COMMAND_TOPIC}" \
        -q "${MQTT_QOS}" \
        -m "${MQTT_COMMAND}"

wait "${SUBSCRIBER_PID}"
SUBSCRIBER_PID=""

grep -Fq "${MQTT_COMMAND}" "${MQTT_ROS_OUTPUT}"

echo "PASSED: MQTT 5 -> ROS 2"


# ------------------------------------------------------------
# TEST 3 - REST Health
# ------------------------------------------------------------

echo
echo "=== 3/5 REST GET /api/health ==="

HEALTH_LOG="$(new_tmp)"
HEALTH_RESPONSE="$(new_tmp)"

start_port_forward "${HEALTH_PORT}" "${HEALTH_LOG}"

HTTP_STATUS="$(
    curl \
        --silent \
        --show-error \
        --http1.1 \
        --output "${HEALTH_RESPONSE}" \
        --write-out '%{http_code}' \
        "http://127.0.0.1:${HEALTH_PORT}/api/health"
)"

[[ "${HTTP_STATUS}" == "200" ]]

python3 - "${HEALTH_RESPONSE}" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())

if data.get("status") != "ok":
    raise SystemExit("ERROR: REST health status is not ok.")

if data.get("service") != "vagotec_backend_service":
    raise SystemExit("ERROR: Unexpected REST service name.")

print("REST health response: VALID")
PY

stop_port_forward

echo "PASSED: REST Health"


# ------------------------------------------------------------
# TEST 4 - REST Telemetry
# ------------------------------------------------------------

echo
echo "=== 4/5 REST GET /api/telemetry/latest ==="

TELEMETRY_LOG="$(new_tmp)"
TELEMETRY_RESPONSE="$(new_tmp)"

start_port_forward "${TELEMETRY_PORT}" "${TELEMETRY_LOG}"

TELEMETRY_STATUS=""

for _ in $(seq 1 30); do
    TELEMETRY_STATUS="$(
        curl \
            --silent \
            --show-error \
            --http1.1 \
            --output "${TELEMETRY_RESPONSE}" \
            --write-out '%{http_code}' \
            "http://127.0.0.1:${TELEMETRY_PORT}/api/telemetry/latest" ||
        true
    )"

    if [[ "${TELEMETRY_STATUS}" == "200" ]]; then
        break
    fi

    sleep 1
done

if [[ "${TELEMETRY_STATUS}" != "200" ]]; then
    echo "ERROR: REST telemetry did not return HTTP 200."
    exit 1
fi

python3 - "${TELEMETRY_RESPONSE}" "${DEVICE_ID}" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())

if data.get("device_id") != sys.argv[2]:
    raise SystemExit("ERROR: Unexpected REST telemetry device_id.")

for field in ("temperature_c", "humidity_percent"):
    if not isinstance(data.get(field), (int, float)):
        raise SystemExit(f"ERROR: Invalid REST telemetry field: {field}")

print("REST telemetry response: VALID")
PY

stop_port_forward

echo "PASSED: REST Telemetry"


# ------------------------------------------------------------
# TEST 5 - REST -> Backend -> ROS 2
# ------------------------------------------------------------

echo
echo "=== 5/5 REST POST /api/commands -> ROS 2 ==="

REST_COMMAND='{"command":"test","value":"backend-rest"}'
REST_ROS_OUTPUT="$(new_tmp)"
COMMAND_LOG="$(new_tmp)"
COMMAND_RESPONSE="$(new_tmp)"

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${SIMULATOR_POD}" -- \
    bash -lc "
        source /opt/ros/jazzy/setup.bash
        source /workspace/install/setup.bash
        export ROS_DOMAIN_ID='${ROS_DOMAIN_ID}'
        timeout 20 ros2 topic echo \
            '${ROS2_COMMAND_TOPIC}' \
            std_msgs/msg/String \
            --once
    " >"${REST_ROS_OUTPUT}" 2>&1 &

SUBSCRIBER_PID=$!

sleep 3

start_port_forward "${COMMAND_PORT}" "${COMMAND_LOG}"

COMMAND_STATUS="$(
    curl \
        --silent \
        --show-error \
        --http1.1 \
        --request POST \
        --header 'Content-Type: application/json' \
        --data "${REST_COMMAND}" \
        --output "${COMMAND_RESPONSE}" \
        --write-out '%{http_code}' \
        "http://127.0.0.1:${COMMAND_PORT}/api/commands"
)"

[[ "${COMMAND_STATUS}" == "202" ]]

python3 - "${COMMAND_RESPONSE}" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text())

if data.get("status") != "accepted":
    raise SystemExit("ERROR: REST command was not accepted.")

print("REST command response: VALID")
PY

wait "${SUBSCRIBER_PID}"
SUBSCRIBER_PID=""

grep -Fq "${REST_COMMAND}" "${REST_ROS_OUTPUT}"

stop_port_forward

echo "PASSED: REST -> ROS 2"

echo
echo "============================================================"
echo " BACKEND FUNCTIONAL TEST PASSED"
echo "============================================================"
echo " ROS 2 -> MQTT 5            : PASSED"
echo " MQTT 5 -> ROS 2            : PASSED"
echo " REST Health                : PASSED"
echo " REST Telemetry             : PASSED"
echo " REST Command -> ROS 2      : PASSED"
echo "============================================================"
