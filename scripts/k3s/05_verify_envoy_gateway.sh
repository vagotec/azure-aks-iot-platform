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

ERRORS=0

echo "========================================"
echo " Verify Envoy Gateway + Platform Gateway"
echo "========================================"

echo
echo "=== Helm Release ==="

if helm status "${RELEASE_NAME}" \
    --namespace "${ENVOY_NAMESPACE}" >/dev/null 2>&1; then

    echo "OK: Envoy Gateway Helm release exists."
else
    echo "ERROR: Envoy Gateway Helm release not found."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "=== Envoy Gateway Controller ==="

if kubectl rollout status \
    deployment/envoy-gateway \
    --namespace "${ENVOY_NAMESPACE}" \
    --timeout=60s; then

    echo "OK: Envoy Gateway controller is available."
else
    echo "ERROR: Envoy Gateway controller is unavailable."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "=== Required Gateway API CRDs ==="

REQUIRED_CRDS=(
    "gatewayclasses.gateway.networking.k8s.io"
    "gateways.gateway.networking.k8s.io"
    "httproutes.gateway.networking.k8s.io"
)

for crd in "${REQUIRED_CRDS[@]}"; do
    if kubectl get crd "${crd}" >/dev/null 2>&1; then
        echo "OK: ${crd}"
    else
        echo "ERROR: Missing CRD: ${crd}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo
echo "=== Platform GatewayClass ==="

if kubectl get gatewayclass "${GATEWAY_CLASS_NAME}" \
    >/dev/null 2>&1; then

    GATEWAYCLASS_ACCEPTED="$(
        kubectl get gatewayclass "${GATEWAY_CLASS_NAME}" \
            -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'
    )"

    if [[ "${GATEWAYCLASS_ACCEPTED}" == "True" ]]; then
        echo "OK: GatewayClass ${GATEWAY_CLASS_NAME} is Accepted."
    else
        echo "ERROR: GatewayClass Accepted=${GATEWAYCLASS_ACCEPTED}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "ERROR: GatewayClass ${GATEWAY_CLASS_NAME} does not exist."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "=== Platform Gateway ==="

if kubectl get gateway "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then

    GATEWAY_PROGRAMMED="$(
        kubectl get gateway "${GATEWAY_NAME}" \
            -n "${K8S_NAMESPACE}" \
            -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
    )"

    if [[ "${GATEWAY_PROGRAMMED}" == "True" ]]; then
        echo "OK: Gateway ${GATEWAY_NAME} is Programmed."
    else
        echo "ERROR: Gateway Programmed=${GATEWAY_PROGRAMMED}"
        ERRORS=$((ERRORS + 1))
    fi

    LISTENER_ACCEPTED="$(
        kubectl get gateway "${GATEWAY_NAME}" \
            -n "${K8S_NAMESPACE}" \
            -o jsonpath="{.status.listeners[?(@.name=='${GATEWAY_HTTP_LISTENER_NAME}')].conditions[?(@.type=='Accepted')].status}"
    )"

    LISTENER_PROGRAMMED="$(
        kubectl get gateway "${GATEWAY_NAME}" \
            -n "${K8S_NAMESPACE}" \
            -o jsonpath="{.status.listeners[?(@.name=='${GATEWAY_HTTP_LISTENER_NAME}')].conditions[?(@.type=='Programmed')].status}"
    )"

    if [[ "${LISTENER_ACCEPTED}" == "True" &&
          "${LISTENER_PROGRAMMED}" == "True" ]]; then
        echo "OK: Listener ${GATEWAY_HTTP_LISTENER_NAME} is Accepted and Programmed."
    else
        echo "ERROR: Listener Accepted=${LISTENER_ACCEPTED}, Programmed=${LISTENER_PROGRAMMED}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "ERROR: Gateway ${GATEWAY_NAME} does not exist."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "=== Current Gateway resources ==="

kubectl get gatewayclass "${GATEWAY_CLASS_NAME}" || true

kubectl get gateway \
    "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o wide || true

echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " Envoy Gateway verification PASSED"
    echo "========================================"
    exit 0
fi

echo " Envoy Gateway verification FAILED"
echo " Errors: ${ERRORS}"
echo "========================================"
exit 1
