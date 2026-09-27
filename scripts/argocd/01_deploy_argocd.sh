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
echo "=== Apply declarative Argo CD configuration ==="

kubectl apply \
  --server-side \
  -k gitops/argocd

echo
echo "=== Wait for Argo CD Application ==="

kubectl wait \
  --for=create \
  application/azure-aks-iot-platform \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=60s

echo
echo "=== Wait for GitOps synchronization ==="

for i in $(seq 1 180); do
  SYNC_STATUS="$(
    kubectl get application azure-aks-iot-platform \
      -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || true
  )"

  HEALTH_STATUS="$(
    kubectl get application azure-aks-iot-platform \
      -n "${ARGOCD_NAMESPACE}" \
      -o jsonpath='{.status.health.status}' 2>/dev/null || true
  )"

  echo "Argo CD: sync=${SYNC_STATUS:-Unknown}, health=${HEALTH_STATUS:-Unknown}"

  if [[ "${SYNC_STATUS}" == "Synced" && "${HEALTH_STATUS}" == "Healthy" ]]; then
    break
  fi

  if [[ "${i}" -eq 180 ]]; then
    echo "ERROR: Argo CD Application did not become Synced and Healthy."
    kubectl get application azure-aks-iot-platform \
      -n "${ARGOCD_NAMESPACE}" \
      -o wide || true
    exit 1
  fi

  sleep 2
done

echo
echo "============================================================"
echo " ARGO CD DEPLOY COMPLETE"
echo " Application: Synced / Healthy"
echo "============================================================"
