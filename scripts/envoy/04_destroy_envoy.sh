#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

echo "========================================"
echo " Destroy Envoy Gateway Controller"
echo "========================================"

if helm status "${ENVOY_GATEWAY_RELEASE}" \
    --namespace "${ENVOY_GATEWAY_NAMESPACE}" >/dev/null 2>&1; then

    helm uninstall "${ENVOY_GATEWAY_RELEASE}" \
        --namespace "${ENVOY_GATEWAY_NAMESPACE}" \
        --wait
else
    echo "Envoy Gateway Helm release already absent."
fi

if kubectl get namespace "${ENVOY_GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
    kubectl delete namespace "${ENVOY_GATEWAY_NAMESPACE}" \
        --wait=true
fi

echo
echo "IMPORTANT:"
echo "GatewayClass, Gateway and HTTPRoute were NOT deleted."
echo "They belong to the GitOps/Argo CD layer."

echo "========================================"
echo " Envoy Gateway controller destroyed"
echo "========================================"
