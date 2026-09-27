#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

ERRORS=0

echo "========================================"
echo " Verify Envoy Gateway Destroy"
echo "========================================"

if helm status "${ENVOY_GATEWAY_RELEASE}" \
    --namespace "${ENVOY_GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Envoy Helm release still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Envoy Helm release absent."
fi

if kubectl get namespace "${ENVOY_GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Envoy namespace still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Envoy namespace absent."
fi

echo
echo "=== GitOps resources must survive ==="

for resource in \
    "gatewayclass/${GATEWAY_CLASS_NAME}" \
    "gateway/${GATEWAY_NAME} -n ${K8S_NAMESPACE}" \
    "httproute/${HTTPROUTE_NAME} -n ${K8S_NAMESPACE}"
do
    if kubectl get ${resource} >/dev/null 2>&1; then
        echo "OK: ${resource} survived."
    else
        echo "ERROR: ${resource} is missing."
        ERRORS=$((ERRORS + 1))
    fi
done

if [[ "${ERRORS}" -ne 0 ]]; then
    echo "========================================"
    echo " Envoy destroy verification FAILED"
    echo "========================================"
    exit 1
fi

echo "========================================"
echo " Envoy destroy verification PASSED"
echo "========================================"
