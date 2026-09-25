#!/usr/bin/env bash

set -euo pipefail

ENVOY_GATEWAY_VERSION="v1.9.1"
NAMESPACE="envoy-gateway-system"
RELEASE_NAME="eg"
CHART="oci://docker.io/envoyproxy/gateway-helm"

echo "========================================"
echo " Azure AKS IoT Platform"
echo " Phase 1.4 - Install Envoy Gateway"
echo "========================================"
echo
echo "Envoy Gateway: ${ENVOY_GATEWAY_VERSION}"
echo

# ------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------

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

if ! kubectl get nodes --no-headers | grep -q " Ready "; then
    echo "ERROR: No Ready Kubernetes node found."
    exit 1
fi

echo "Pre-flight checks: OK"

# ------------------------------------------------------------
# Check current Gateway API state
# ------------------------------------------------------------

echo
echo "=== Existing Gateway API CRDs ==="

if kubectl get crd gateways.gateway.networking.k8s.io \
    >/dev/null 2>&1; then

    echo "Gateway API CRDs are already installed."
    echo
    kubectl get crd | grep 'gateway.networking.k8s.io' || true

    echo
    echo "ERROR:"
    echo "Gateway API CRDs already exist."
    echo "This script will not overwrite an existing CRD installation."
    echo "Verify ownership/version before continuing."
    exit 1
else
    echo "Gateway API CRDs are not installed."
    echo "They will be installed by the Envoy Gateway Helm chart."
fi

# ------------------------------------------------------------
# Prevent accidental duplicate installation
# ------------------------------------------------------------

echo
echo "=== Existing Envoy Gateway Release ==="

if helm status "${RELEASE_NAME}" \
    --namespace "${NAMESPACE}" >/dev/null 2>&1; then

    echo "ERROR: Envoy Gateway Helm release already exists."
    echo "Existing installation will NOT be modified."
    exit 1
else
    echo "No existing Envoy Gateway Helm release found."
fi

# ------------------------------------------------------------
# Install Gateway API CRDs + Envoy Gateway
# ------------------------------------------------------------

echo
echo "Installing Gateway API CRDs and Envoy Gateway..."

helm install "${RELEASE_NAME}" \
    "${CHART}" \
    --version "${ENVOY_GATEWAY_VERSION}" \
    --namespace "${NAMESPACE}" \
    --create-namespace

# ------------------------------------------------------------
# Wait for controller
# ------------------------------------------------------------

echo
echo "Waiting for Envoy Gateway controller..."

kubectl wait \
    --namespace "${NAMESPACE}" \
    deployment/envoy-gateway \
    --for=condition=Available \
    --timeout=5m

# ------------------------------------------------------------
# Basic result
# ------------------------------------------------------------

echo
echo "=== Envoy Gateway Pods ==="
kubectl get pods -n "${NAMESPACE}"

echo
echo "=== Gateway API CRDs ==="
kubectl get crd | grep 'gateway.networking.k8s.io' || true

echo
echo "=== Envoy Gateway CRDs ==="
kubectl get crd | grep 'gateway.envoyproxy.io' || true

echo
echo "========================================"
echo " Phase 1.4 completed successfully"
echo "========================================"
echo
echo "Gateway API CRDs: installed"
echo "Envoy Gateway:     installed"
echo
echo "Next step:"
echo "  05_verify_envoy_gateway.sh"
