#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

K3S_IMAGE_REF="docker.io/library/${ROS2_SIMULATOR_IMAGE}"
ERRORS=0

echo "========================================"
echo " Phase 2B.6 - Verify Simulator Destroy"
echo "========================================"

echo
echo "=== Deployment ==="

if kubectl get deployment "${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then

    echo "ERROR: Simulator deployment still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Simulator deployment absent."
fi


echo
echo "=== Simulator Pods ==="

POD_COUNT="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l app.kubernetes.io/name=ros2-simulator \
        --no-headers 2>/dev/null |
        wc -l
)"

if [[ "${POD_COUNT}" -eq 0 ]]; then
    echo "OK: Simulator pods absent."
else
    echo "ERROR: ${POD_COUNT} simulator pod(s) still exist."
    ERRORS=$((ERRORS + 1))
fi


echo
echo "=== K3s Simulator Image ==="

if sudo k3s ctr -n k8s.io images list -q \
    | grep -Fxq "${K3S_IMAGE_REF}"; then

    echo "ERROR: Simulator image still exists in K3s:"
    echo "       ${K3S_IMAGE_REF}"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Simulator image absent from K3s."
fi


echo
echo "=== Docker Simulator Image ==="

if docker image inspect "${ROS2_SIMULATOR_IMAGE}" >/dev/null 2>&1; then
    echo "ERROR: Simulator image still exists in Docker:"
    echo "       ${ROS2_SIMULATOR_IMAGE}"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Simulator image absent from Docker."
fi


echo
echo "=== Mosquitto must remain running ==="

MOSQUITTO_READY="$(
    kubectl get deployment "${MOSQUITTO_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true
)"

if [[ "${MOSQUITTO_READY:-0}" == "1" ]]; then
    echo "OK: Mosquitto remains running."
else
    echo "ERROR: Mosquitto is not healthy."
    ERRORS=$((ERRORS + 1))
fi


echo
echo "=== K3s must remain running ==="

if systemctl is-active --quiet k3s; then
    echo "OK: K3s remains running."
else
    echo "ERROR: K3s is not running."
    ERRORS=$((ERRORS + 1))
fi


echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " Phase 2B destroy verification PASSED"
    echo "========================================"
else
    echo " Phase 2B destroy verification FAILED"
    echo " Errors: ${ERRORS}"
    echo "========================================"
    exit 1
fi
