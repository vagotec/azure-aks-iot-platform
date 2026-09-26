#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="v3.5.3"
ARGOCD_NAMESPACE="argocd"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "============================================================"
echo " DESTROY ARGO CD ${ARGOCD_VERSION}"
echo "============================================================"

if kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo
  echo "=== Delete pinned Argo CD manifest ==="

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
else
  echo
  echo "Argo CD namespace does not exist."
fi

echo
echo "============================================================"
echo " ARGO CD DESTROY COMPLETE"
echo "============================================================"
