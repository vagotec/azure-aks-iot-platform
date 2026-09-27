#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ARGOCD_VERSION="v3.5.3"
ARGOCD_NAMESPACE="argocd"
APPLICATION_NAME="azure-aks-iot-platform"
ARGOCD_MANIFEST="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

cd "${PROJECT_ROOT}"

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
    application/"${APPLICATION_NAME}" \
    -n "${ARGOCD_NAMESPACE}" \
    --timeout=60s

echo
echo "=== Wait for GitOps application namespace ==="

for i in $(seq 1 60); do
    if kubectl get namespace azure-aks-iot >/dev/null 2>&1; then
        echo "OK: namespace azure-aks-iot exists."
        break
    fi

    if [[ "${i}" -eq 60 ]]; then
        echo "ERROR: GitOps namespace azure-aks-iot was not created."
        kubectl get application "${APPLICATION_NAME}" \
            -n "${ARGOCD_NAMESPACE}" \
            -o wide || true
        exit 1
    fi

    sleep 2
done

echo
echo "=== Bootstrap local Kubernetes secrets ==="

"${SCRIPT_DIR}/00_bootstrap_local_secrets.sh"

echo
echo "=== Wait for GitOps synchronization ==="

for i in $(seq 1 180); do
    SYNC_STATUS="$(
        kubectl get application "${APPLICATION_NAME}" \
            -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.sync.status}' 2>/dev/null || true
    )"

    HEALTH_STATUS="$(
        kubectl get application "${APPLICATION_NAME}" \
            -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.health.status}' 2>/dev/null || true
    )"

    echo "Argo CD: sync=${SYNC_STATUS:-Unknown}, health=${HEALTH_STATUS:-Unknown}"

    if [[ "${SYNC_STATUS}" == "Synced" && "${HEALTH_STATUS}" == "Healthy" ]]; then
        break
    fi

    if [[ "${i}" -eq 180 ]]; then
        echo "ERROR: Argo CD Application did not become Synced and Healthy."

        kubectl get application "${APPLICATION_NAME}" \
            -n "${ARGOCD_NAMESPACE}" \
            -o wide || true

        kubectl get pods \
            -n azure-aks-iot \
            -o wide || true

        kubectl get events \
            -n azure-aks-iot \
            --sort-by='.lastTimestamp' |
            tail -50 || true

        exit 1
    fi

    sleep 2
done

echo
echo "============================================================"
echo " ARGO CD DEPLOY COMPLETE"
echo " Application: Synced / Healthy"
echo "============================================================"
