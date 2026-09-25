#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "========================================"
echo " Phase 2A.3 - MQTT 5 QoS ${MQTT_QOS} Test"
echo "========================================"

POD="$(
    kubectl get pod \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=mosquitto \
        -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${POD}" ]]; then
    echo "ERROR: Mosquitto pod not found."
    exit 1
fi

OUTPUT_FILE="$(mktemp)"
SUB_PID=""

cleanup() {
    if [[ -n "${SUB_PID}" ]] && kill -0 "${SUB_PID}" 2>/dev/null; then
        kill "${SUB_PID}" 2>/dev/null || true
        wait "${SUB_PID}" 2>/dev/null || true
    fi

    rm -f "${OUTPUT_FILE}"
}

trap cleanup EXIT

echo "Pod:     ${POD}"
echo "Topic:   ${MQTT_TEST_TOPIC}"
echo "Message: ${MQTT_TEST_MESSAGE}"
echo "QoS:     ${MQTT_QOS}"

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${POD}" -- \
    mosquitto_sub \
        -V mqttv5 \
        -h 127.0.0.1 \
        -p 1883 \
        -q "${MQTT_QOS}" \
        -t "${MQTT_TEST_TOPIC}" \
        -C 1 \
        -W 10 \
        > "${OUTPUT_FILE}" &

SUB_PID=$!

sleep 1

kubectl exec \
    -n "${K8S_NAMESPACE}" \
    "${POD}" -- \
    mosquitto_pub \
        -V mqttv5 \
        -h 127.0.0.1 \
        -p 1883 \
        -q "${MQTT_QOS}" \
        -t "${MQTT_TEST_TOPIC}" \
        -m "${MQTT_TEST_MESSAGE}"

wait "${SUB_PID}"
SUB_PID=""

RECEIVED_MESSAGE="$(cat "${OUTPUT_FILE}")"

echo
echo "Received: ${RECEIVED_MESSAGE}"

if [[ "${RECEIVED_MESSAGE}" != "${MQTT_TEST_MESSAGE}" ]]; then
    echo "FAILED: MQTT message does not match."
    exit 1
fi

echo
echo "PASSED: MQTT 5 QoS ${MQTT_QOS} publish/subscribe works."
