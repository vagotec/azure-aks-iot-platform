#!/usr/bin/env bash
set -euo pipefail

ARGOCD_VERSION="v3.5.3"
ARGOCD_NAMESPACE="argocd"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "============================================================"
echo " DEPLOY ARGO CD ${ARGOCD_VERSION}"
echo "============================================================"

echo
echo "=== Create namespace if required ==="
kubectl create namespace "${ARGOCD_NAMESPACE}" \
  --dry-run=client \
  -o yaml |
kubectl apply -f -

echo
echo "=== Apply pinned official Argo CD manifest ==="
kubectl apply \
  --server-side \
  --force-conflicts \
  -n "${ARGOCD_NAMESPACE}" \
  -f "${ARGOCD_MANIFEST}"

echo
echo "=== Wait for Deployments ==="
kubectl wait \
  --for=condition=Available \
  deployment \
  --all \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=300s

echo
echo "=== Wait for Application Controller ==="
kubectl rollout status \
  statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=300s

echo
echo "============================================================"
echo " ARGO CD DEPLOY COMPLETE"
echo "============================================================"
