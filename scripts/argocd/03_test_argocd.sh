#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NAMESPACE="argocd"

echo "============================================================"
echo " FUNCTIONAL TEST ARGO CD"
echo "============================================================"

echo
echo "=== Test Argo CD API Server from inside cluster ==="

kubectl run argocd-api-test \
  --namespace "${ARGOCD_NAMESPACE}" \
  --image=curlimages/curl:8.17.0 \
  --restart=Never \
  --rm \
  --attach \
  --quiet \
  --command -- \
  curl \
    --fail \
    --silent \
    --show-error \
    --insecure \
    https://argocd-server.argocd.svc.cluster.local/api/version

echo
echo
echo "=== Verify existing IoT platform remains healthy ==="

kubectl get deployments \
  -n azure-aks-iot

kubectl wait \
  --for=condition=Available \
  deployment \
  --all \
  -n azure-aks-iot \
  --timeout=120s

echo
echo "============================================================"
echo " ARGO CD FUNCTIONAL TEST COMPLETE"
echo "============================================================"
