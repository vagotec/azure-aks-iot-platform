#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"
GATEWAY_DIR="${PROJECT_ROOT}/kubernetes/k3s/gateway"

ENVOY_GATEWAY_VERSION="v1.9.1"
ENVOY_NAMESPACE="envoy-gateway-system"
RELEASE_NAME="eg"
CHART="oci://docker.io/envoyproxy/gateway-helm"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing configuration: ${CONFIG_FILE}"
    exit 1
fi

set -a
source "${CONFIG_FILE}"
set +a

required_variables=(
    PROJECT_NAME
    K8S_NAMESPACE
    GATEWAY_NAME
    GATEWAY_CLASS_NAME
    GATEWAY_HTTP_PORT
    GATEWAY_HTTP_LISTENER_NAME
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        echo "ERROR: Required configuration variable is empty: ${variable}"
        exit 1
    fi
done

GATEWAYCLASS_GENERATED="${GATEWAY_DIR}/gatewayclass.generated.yaml"
GATEWAY_GENERATED="${GATEWAY_DIR}/gateway.generated.yaml"

echo "========================================"
echo " Azure AKS IoT Platform"
echo " Install Envoy Gateway + Platform Gateway"
echo "========================================"
echo
echo "Envoy Gateway: ${ENVOY_GATEWAY_VERSION}"

echo
echo "=== Pre-flight checks ==="

for command in kubectl helm envsubst; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: ${command} is not installed."
        exit 1
    fi
done

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "ERROR: Kubernetes cluster is not reachable."
    exit 1
fi

if ! kubectl get nodes --no-headers | grep -q " Ready "; then
    echo "ERROR: No Ready Kubernetes node found."
    exit 1
fi

echo
echo "=== Ensure shared project namespace ==="

kubectl create namespace "${K8S_NAMESPACE}" \
  --dry-run=client \
  -o yaml |
  kubectl apply -f -

echo "Pre-flight checks: OK"

echo
echo "=== Install Envoy Gateway ==="

if helm status "${RELEASE_NAME}" \
    --namespace "${ENVOY_NAMESPACE}" >/dev/null 2>&1; then

    echo "Envoy Gateway Helm release already exists."
    echo "Existing release will be reused."
else
    if kubectl get crd gateways.gateway.networking.k8s.io \
        >/dev/null 2>&1; then

        echo "ERROR: Gateway API CRDs exist without the expected Helm release."
        echo "Verify their ownership before continuing."
        exit 1
    fi

    helm install "${RELEASE_NAME}" \
        "${CHART}" \
        --version "${ENVOY_GATEWAY_VERSION}" \
        --namespace "${ENVOY_NAMESPACE}" \
        --create-namespace
fi

echo
echo "=== Wait for Envoy Gateway controller ==="

kubectl wait \
    --namespace "${ENVOY_NAMESPACE}" \
    deployment/envoy-gateway \
    --for=condition=Available \
    --timeout=5m

echo
echo "=== Render Platform Gateway resources ==="

envsubst \
    < "${GATEWAY_DIR}/gatewayclass.yaml.template" \
    > "${GATEWAYCLASS_GENERATED}"

envsubst \
    < "${GATEWAY_DIR}/gateway.yaml.template" \
    > "${GATEWAY_GENERATED}"

if grep -RInE \
    '\$\{[A-Za-z_][A-Za-z0-9_]*\}' \
    "${GATEWAYCLASS_GENERATED}" \
    "${GATEWAY_GENERATED}"; then

    echo "ERROR: Unresolved Gateway template variable."
    exit 1
fi

echo
echo "=== Server-side validation ==="

kubectl apply \
    --dry-run=server \
    -f "${GATEWAYCLASS_GENERATED}"

kubectl apply \
    --dry-run=server \
    -f "${GATEWAY_GENERATED}"

echo
echo "=== Apply GatewayClass ==="

kubectl apply \
    -f "${GATEWAYCLASS_GENERATED}"

echo
echo "=== Wait for GatewayClass acceptance ==="

kubectl wait \
    --for=condition=Accepted \
    gatewayclass/"${GATEWAY_CLASS_NAME}" \
    --timeout=120s

echo
echo "=== Apply Gateway ==="

kubectl apply \
    -f "${GATEWAY_GENERATED}"

echo
echo "=== Wait for Gateway programming ==="

kubectl wait \
    --for=condition=Programmed \
    gateway/"${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=180s

echo
echo "=== Result ==="

kubectl get gatewayclass "${GATEWAY_CLASS_NAME}"

kubectl get gateway \
    "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o wide

echo
echo "========================================"
echo " Envoy Gateway installation PASSED"
echo "========================================"
