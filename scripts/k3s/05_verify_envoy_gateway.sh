#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="envoy-gateway-system"
RELEASE_NAME="eg"

echo "========================================"
echo " Azure AKS IoT Platform"
echo " Phase 1.5 - Verify Envoy Gateway"
echo "========================================"
echo

ERRORS=0

# ------------------------------------------------------------
# 1. Helm release
# ------------------------------------------------------------

echo "=== Helm Release ==="

if helm status "${RELEASE_NAME}" \
    --namespace "${NAMESPACE}" >/dev/null 2>&1; then
    echo "OK: Envoy Gateway Helm release exists."
    helm list --namespace "${NAMESPACE}"
else
    echo "ERROR: Envoy Gateway Helm release not found."
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------
# 2. Envoy Gateway controller
# ------------------------------------------------------------

echo
echo "=== Envoy Gateway Controller ==="

if kubectl rollout status \
    deployment/envoy-gateway \
    --namespace "${NAMESPACE}" \
    --timeout=60s; then

    echo "OK: Envoy Gateway controller is available."
else
    echo "ERROR: Envoy Gateway controller is not available."
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------
# 3. Required Gateway API CRDs
# ------------------------------------------------------------

echo
echo "=== Required Gateway API CRDs ==="

REQUIRED_CRDS=(
    "gatewayclasses.gateway.networking.k8s.io"
    "gateways.gateway.networking.k8s.io"
    "httproutes.gateway.networking.k8s.io"
    "tcproutes.gateway.networking.k8s.io"
)

for crd in "${REQUIRED_CRDS[@]}"; do
    if kubectl get crd "${crd}" >/dev/null 2>&1; then
        echo "OK: ${crd}"
    else
        echo "ERROR: Missing CRD: ${crd}"
        ERRORS=$((ERRORS + 1))
    fi
done

# ------------------------------------------------------------
# 4. GatewayClass
# ------------------------------------------------------------

echo
echo "=== GatewayClass ==="

kubectl get gatewayclass || true

if kubectl get gatewayclass envoy >/dev/null 2>&1; then
    echo "OK: GatewayClass 'envoy' exists."
else
    echo "INFO: GatewayClass 'envoy' does not exist yet."
    echo "      We will create it later with our platform configuration."
fi

# ------------------------------------------------------------
# 5. Current controller pods
# ------------------------------------------------------------

echo
echo "=== Envoy Gateway Namespace ==="

kubectl get pods -n "${NAMESPACE}"

# ------------------------------------------------------------
# Result
# ------------------------------------------------------------

echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " Envoy Gateway verification PASSED"
    echo "========================================"
    echo
    echo "K3s + Gateway API + Envoy Gateway are ready."
    exit 0
else
    echo " Envoy Gateway verification FAILED"
    echo " Errors: ${ERRORS}"
    echo "========================================"
    exit 1
fi
