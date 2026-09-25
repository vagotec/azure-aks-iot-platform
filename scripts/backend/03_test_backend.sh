#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

REST_PORT_FORWARD=18080

PF_PID=""
TMP_FILES=()

cleanup() {
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

start_port_forward() {
    local log_file="$1"

    kubectl port-forward \
        -n "${K8S_NAMESPACE}" \
        service/"${BACKEND_NAME}" \
        "${REST_PORT_FORWARD}:${REST_PORT}" \
        >"${log_file}" 2>&1 &

    PF_PID=$!

    for _ in $(seq 1 30); do
        if curl \
            --silent \
            --fail \
            --http1.1 \
            "http://127.0.0.1:${REST_PORT_FORWARD}/api/health" \
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

echo
echo "Backend Pod  : ${BACKEND_POD}"
echo "Mosquitto Pod: ${MOSQUITTO_POD}"
echo "Simulator Pod: ${SIMULATOR_POD}"

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
    raise SystemExit(
        "ERROR: Unexpected telemetry device_id."
    )

for field in (
    "temperature_c",
    "humidity_percent",
):
    if not isinstance(
        data.get(field),
        (int, float),
    ):
        raise SystemExit(
            f"ERROR: Invalid telemetry field: {field}"
        )

print("Telemetry payload: VALID")
PY

echo "PASSED: ROS 2 -> Backend -> MQTT 5"

# ------------------------------------------------------------
# TEST 2 - MQTT 5 -> Backend -> ROS 2 Service -> Simulator
# ------------------------------------------------------------

echo
echo "=== 2/5 MQTT 5 -> Backend -> ROS 2 Service -> Simulator ==="

MQTT_COMMAND='{"command":"test","value":"backend-mqtt"}'

BEFORE_LOG_COUNT="$(
    kubectl logs \
        -n "${K8S_NAMESPACE}" \
        "${SIMULATOR_POD}" |
        grep -Fc \
            "Simulator executed command 'test' with value 'backend-mqtt'" ||
    true
)"

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

MQTT_EXECUTED=0

for _ in $(seq 1 30); do
    AFTER_LOG_COUNT="$(
        kubectl logs \
            -n "${K8S_NAMESPACE}" \
            "${SIMULATOR_POD}" |
            grep -Fc \
                "Simulator executed command 'test' with value 'backend-mqtt'" ||
        true
    )"

    if (( AFTER_LOG_COUNT > BEFORE_LOG_COUNT )); then
        MQTT_EXECUTED=1
        break
    fi

    sleep 0.2
done

if [[ "${MQTT_EXECUTED}" -ne 1 ]]; then
    echo "ERROR: Simulator did not execute MQTT command."
    exit 1
fi

echo "PASSED: MQTT 5 -> Backend -> ROS 2 Service -> Simulator"

# ------------------------------------------------------------
# Start one REST port-forward for tests 3-5
# ------------------------------------------------------------

PF_LOG="$(new_tmp)"
start_port_forward "${PF_LOG}"

# ------------------------------------------------------------
# TEST 3 - REST Health
# ------------------------------------------------------------

echo
echo "=== 3/5 REST GET /api/health ==="

HEALTH_RESPONSE="$(new_tmp)"

HTTP_STATUS="$(
    curl \
        --silent \
        --show-error \
        --http1.1 \
        --output "${HEALTH_RESPONSE}" \
        --write-out '%{http_code}' \
        "http://127.0.0.1:${REST_PORT_FORWARD}/api/health"
)"

if [[ "${HTTP_STATUS}" != "200" ]]; then
    echo "ERROR: REST health returned HTTP ${HTTP_STATUS}."
    cat "${HEALTH_RESPONSE}"
    exit 1
fi

python3 - "${HEALTH_RESPONSE}" <<'PY'
import json
import pathlib
import sys

data = json.loads(
    pathlib.Path(sys.argv[1]).read_text()
)

if data.get("status") != "ok":
    raise SystemExit(
        "ERROR: REST health status is not ok."
    )

if data.get("service") != "vagotec_backend_service":
    raise SystemExit(
        "ERROR: Unexpected REST service name."
    )

print("REST health response: VALID")
PY

echo "PASSED: REST Health"

# ------------------------------------------------------------
# TEST 4 - REST Telemetry
# ------------------------------------------------------------

echo
echo "=== 4/5 REST GET /api/telemetry/latest ==="

TELEMETRY_RESPONSE="$(new_tmp)"
TELEMETRY_STATUS=""

for _ in $(seq 1 30); do
    TELEMETRY_STATUS="$(
        curl \
            --silent \
            --show-error \
            --http1.1 \
            --output "${TELEMETRY_RESPONSE}" \
            --write-out '%{http_code}' \
            "http://127.0.0.1:${REST_PORT_FORWARD}/api/telemetry/latest" ||
        true
    )"

    if [[ "${TELEMETRY_STATUS}" == "200" ]]; then
        break
    fi

    sleep 1
done

if [[ "${TELEMETRY_STATUS}" != "200" ]]; then
    echo "ERROR: REST telemetry did not return HTTP 200."
    cat "${TELEMETRY_RESPONSE}"
    exit 1
fi

python3 - \
    "${TELEMETRY_RESPONSE}" \
    "${DEVICE_ID}" <<'PY'
import json
import pathlib
import sys

data = json.loads(
    pathlib.Path(sys.argv[1]).read_text()
)

if data.get("device_id") != sys.argv[2]:
    raise SystemExit(
        "ERROR: Unexpected REST telemetry device_id."
    )

for field in (
    "temperature_c",
    "humidity_percent",
):
    if not isinstance(
        data.get(field),
        (int, float),
    ):
        raise SystemExit(
            f"ERROR: Invalid REST telemetry field: {field}"
        )

print("REST telemetry response: VALID")
PY

echo "PASSED: REST Telemetry"

# ------------------------------------------------------------
# TEST 5 - REST -> Backend -> ROS 2 Service -> Simulator
#          -> Backend -> REST
# ------------------------------------------------------------

echo
echo "=== 5/5 REST Command full round-trip ==="

REST_COMMAND='{"command":"test","value":"backend-rest"}'
COMMAND_RESPONSE="$(new_tmp)"

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
        "http://127.0.0.1:${REST_PORT_FORWARD}/api/commands"
)"

echo "HTTP status : ${COMMAND_STATUS}"
echo -n "Response    : "
cat "${COMMAND_RESPONSE}"
echo

if [[ "${COMMAND_STATUS}" != "200" ]]; then
    echo "ERROR: REST command did not return HTTP 200."
    exit 1
fi

python3 - "${COMMAND_RESPONSE}" <<'PY'
import json
import pathlib
import sys

data = json.loads(
    pathlib.Path(sys.argv[1]).read_text()
)

if data.get("success") is not True:
    raise SystemExit(
        "ERROR: Simulator response success is not true."
    )

if data.get("status") != "executed":
    raise SystemExit(
        "ERROR: Simulator response status is not executed."
    )

expected = (
    "Simulator executed command 'test' "
    "with value 'backend-rest'"
)

if data.get("message") != expected:
    raise SystemExit(
        "ERROR: Unexpected simulator response message.\n"
        f"Expected: {expected}\n"
        f"Actual:   {data.get('message')}"
    )

print("REST device command response: VALID")
print("Device execution acknowledgement: VALID")
PY

echo "PASSED: REST -> Backend -> ROS 2 -> Simulator -> REST"

echo
echo "============================================================"
echo " BACKEND FUNCTIONAL TEST PASSED"
echo "============================================================"
echo " ROS 2 -> Backend -> MQTT 5                 : PASSED"
echo " MQTT 5 -> Backend -> ROS 2 -> Simulator    : PASSED"
echo " REST Health                               : PASSED"
echo " REST Telemetry                            : PASSED"
echo " REST -> Backend -> ROS 2 -> Simulator"
echo "      -> Backend -> REST                   : PASSED"
echo "============================================================"
