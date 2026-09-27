#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing configuration: ${CONFIG_FILE}"
    exit 1
fi

set -a
source "${CONFIG_FILE}"
set +a

required_variables=(
    ENVOY_GATEWAY_VERSION
    ENVOY_GATEWAY_NAMESPACE
    ENVOY_GATEWAY_RELEASE
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        echo "ERROR: Required configuration variable is empty: ${variable}"
        exit 1
    fi
done

CHART="oci://docker.io/envoyproxy/gateway-helm"

echo "========================================"
echo " Deploy Envoy Gateway Controller"
echo "========================================"
echo "Version:   ${ENVOY_GATEWAY_VERSION}"
echo "Namespace: ${ENVOY_GATEWAY_NAMESPACE}"
echo "Release:   ${ENVOY_GATEWAY_RELEASE}"

for command in kubectl helm; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: ${command} is not installed."
        exit 1
    fi
done

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Kubernetes cluster is not reachable."
    exit 1
fi

if helm status "${ENVOY_GATEWAY_RELEASE}" \
    --namespace "${ENVOY_GATEWAY_NAMESPACE}" >/dev/null 2>&1; then

    echo "Envoy Gateway Helm release already exists."
else
    helm install "${ENVOY_GATEWAY_RELEASE}" \
        "${CHART}" \
        --version "${ENVOY_GATEWAY_VERSION}" \
        --namespace "${ENVOY_GATEWAY_NAMESPACE}" \
        --create-namespace
fi

kubectl wait \
    --namespace "${ENVOY_GATEWAY_NAMESPACE}" \
    deployment/envoy-gateway \
    --for=condition=Available \
    --timeout=5m

echo "========================================"
echo " Envoy Gateway deployment PASSED"
echo "========================================"
