#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

ENVOY_NAMESPACE="envoy-gateway-system"
RELEASE_NAME="eg"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing configuration: ${CONFIG_FILE}"
    exit 1
fi

set -a
source "${CONFIG_FILE}"
set +a

echo "========================================"
echo " Destroy Platform Gateway + Envoy Gateway"
echo "========================================"

echo
echo "=== Remove application HTTPRoute if present ==="

kubectl delete httproute "${HTTPROUTE_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --ignore-not-found=true

echo
echo "=== Remove Platform Gateway ==="

kubectl delete gateway "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --ignore-not-found=true \
    --wait=true

echo
echo "=== Remove Platform GatewayClass ==="

kubectl delete gatewayclass "${GATEWAY_CLASS_NAME}" \
    --ignore-not-found=true \
    --wait=true

echo
echo "=== Remove Envoy Gateway Helm release ==="

if helm status "${RELEASE_NAME}" \
    -n "${ENVOY_NAMESPACE}" >/dev/null 2>&1; then

    helm uninstall "${RELEASE_NAME}" \
        -n "${ENVOY_NAMESPACE}" \
        --wait
else
    echo "Envoy Gateway Helm release already absent."
fi

if kubectl get namespace "${ENVOY_NAMESPACE}" \
    >/dev/null 2>&1; then

    kubectl delete namespace "${ENVOY_NAMESPACE}" \
        --wait=true
fi

echo
echo "========================================"
echo " Platform Gateway + Envoy Gateway destroyed"
echo "========================================"
