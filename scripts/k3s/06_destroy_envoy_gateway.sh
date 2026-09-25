#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="envoy-gateway-system"
RELEASE_NAME="eg"

echo "========================================"
echo " Phase 1.6 - Destroy Envoy Gateway"
echo "========================================"

if helm status "${RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "Removing Envoy Gateway..."
    helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" --wait
else
    echo "Envoy Gateway release already absent."
fi

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    echo "Removing Envoy Gateway namespace..."
    kubectl delete namespace "${NAMESPACE}" --wait=true
fi

echo
echo "Envoy Gateway destroyed."
