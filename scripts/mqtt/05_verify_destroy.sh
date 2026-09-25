#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/config/edge.env"

source "${ENV_FILE}"

ERRORS=0
IMAGE_REF="docker.io/library/${MOSQUITTO_IMAGE}"

echo "========================================"
echo " Phase 2A.5 - Verify Mosquitto Destroy"
echo "========================================"

echo
echo "=== Deployment ==="
if kubectl get deployment "${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Mosquitto deployment still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Mosquitto deployment absent."
fi

echo
echo "=== Service ==="
if kubectl get service "${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Mosquitto service still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Mosquitto service absent."
fi

echo
echo "=== PVC ==="
if kubectl get pvc "${MOSQUITTO_PVC}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Mosquitto PVC still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Mosquitto PVC absent."
fi

echo
echo "=== Namespace ==="
if kubectl get namespace "${K8S_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Project namespace still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Project namespace absent."
fi

echo
echo "=== K3s container image ==="
if sudo k3s ctr images list -q | grep -Fxq "${IMAGE_REF}"; then
    echo "ERROR: Mosquitto image still exists:"
    echo "       ${IMAGE_REF}"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Mosquitto image absent from K3s containerd."
fi

echo
echo "=== K3s itself ==="
if systemctl is-active --quiet k3s; then
    echo "OK: K3s remains running."
else
    echo "ERROR: K3s is not running."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " Phase 2A destroy verification PASSED"
    echo "========================================"
else
    echo " Phase 2A destroy verification FAILED"
    echo " Errors: ${ERRORS}"
    echo "========================================"
    exit 1
fi
