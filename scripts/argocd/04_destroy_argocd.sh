#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="v3.5.3"
ARGOCD_NAMESPACE="argocd"
APPLICATION_NAME="azure-aks-iot-platform"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "============================================================"
echo " DESTROY ARGO CD ${ARGOCD_VERSION}"
echo "============================================================"

if ! kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
    echo
    echo "Argo CD namespace does not exist."
    echo
    echo "============================================================"
    echo " ARGO CD DESTROY COMPLETE"
    echo "============================================================"
    exit 0
fi

echo
echo "=== Remove Argo CD Application NON-CASCADING ==="

if kubectl get application "${APPLICATION_NAME}" \
    -n "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then

    # Explicitly remove any resource finalizer.
    # The platform resources must survive destruction of the Argo CD layer.
    kubectl patch application "${APPLICATION_NAME}" \
        -n "${ARGOCD_NAMESPACE}" \
        --type=merge \
        -p '{"metadata":{"finalizers":null}}'

    kubectl delete application "${APPLICATION_NAME}" \
        -n "${ARGOCD_NAMESPACE}" \
        --wait=true \
        --timeout=120s
else
    echo "Application ${APPLICATION_NAME} already absent."
fi

echo
echo "=== Delete pinned Argo CD installation ==="

kubectl delete \
    -n "${ARGOCD_NAMESPACE}" \
    -f "${ARGOCD_MANIFEST}" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=300s

echo
echo "=== Delete Argo CD namespace ==="

kubectl delete namespace "${ARGOCD_NAMESPACE}" \
    --ignore-not-found=true \
    --wait=true \
    --timeout=300s

echo
echo "============================================================"
echo " ARGO CD DESTROY COMPLETE"
echo "============================================================"
