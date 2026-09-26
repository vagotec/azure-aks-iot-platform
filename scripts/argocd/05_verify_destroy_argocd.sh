#!/usr/bin/env bash
set -euo pipefail

ARGOCD_NAMESPACE="argocd"

echo "============================================================"
echo " VERIFY ARGO CD DESTROY"
echo "============================================================"

FAILED=0

echo
echo "=== Namespace ==="

if kubectl get namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1; then
  echo "FAIL: namespace ${ARGOCD_NAMESPACE} still exists"
  FAILED=1
else
  echo "OK: namespace ${ARGOCD_NAMESPACE} is absent"
fi

echo
echo "=== Argo CD CRDs ==="

for crd in \
  applications.argoproj.io \
  applicationsets.argoproj.io \
  appprojects.argoproj.io
do
  if kubectl get crd "${crd}" >/dev/null 2>&1; then
    echo "FAIL: CRD ${crd} still exists"
    FAILED=1
  else
    echo "OK: CRD ${crd} is absent"
  fi
done

echo
echo "=== Argo CD cluster-scoped resources ==="

if kubectl get clusterrole,clusterrolebinding \
  -o name |
  grep -E 'argocd' >/dev/null 2>&1
then
  echo "FAIL: Argo CD cluster-scoped RBAC resources still exist"
  kubectl get clusterrole,clusterrolebinding \
    -o name |
    grep -E 'argocd' || true
  FAILED=1
else
  echo "OK: no Argo CD cluster-scoped RBAC resources remain"
fi

echo
echo "=== Existing IoT platform ==="

kubectl get deployments \
  -n azure-aks-iot

if [ "${FAILED}" -ne 0 ]; then
  echo
  echo "FAIL: Argo CD destroy verification failed"
  exit 1
fi

echo
echo "============================================================"
echo " ARGO CD DESTROY VERIFIED"
echo "============================================================"
