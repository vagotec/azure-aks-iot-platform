#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NAMESPACE="argocd"

echo "============================================================"
echo " VERIFY ARGO CD"
echo "============================================================"

echo
echo "=== Namespace ==="
kubectl get namespace "${ARGOCD_NAMESPACE}"

echo
echo "=== Pods ==="
kubectl get pods \
  -n "${ARGOCD_NAMESPACE}" \
  -o wide

echo
echo "=== Deployments ==="
kubectl get deployments \
  -n "${ARGOCD_NAMESPACE}"

echo
echo "=== StatefulSet ==="
kubectl get statefulset \
  argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}"

echo
echo "=== Services ==="
kubectl get services \
  -n "${ARGOCD_NAMESPACE}"

echo
echo "=== Argo CD CRDs ==="
for crd in \
  applications.argoproj.io \
  applicationsets.argoproj.io \
  appprojects.argoproj.io
do
  kubectl get crd "${crd}"
done

echo
echo "=== Wait for Deployments ==="
kubectl wait \
  --for=condition=Available \
  deployment \
  --all \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=120s

echo
echo "=== Verify Application Controller ==="
kubectl rollout status \
  statefulset/argocd-application-controller \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=120s

echo
echo "============================================================"
echo " ARGO CD VERIFY COMPLETE"
echo "============================================================"
