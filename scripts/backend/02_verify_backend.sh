#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

LABEL="app.kubernetes.io/name=backend"

echo "============================================================"
echo " VERIFY C++ BACKEND SERVICE"
echo "============================================================"

kubectl rollout status \
    deployment/"${BACKEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s

READY="$(
    kubectl get deployment "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY:-0}" != "1" ]]; then
    echo "ERROR: Backend does not have exactly one ready replica."
    exit 1
fi

STRATEGY="$(
    kubectl get deployment "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.spec.strategy.type}'
)"

if [[ "${STRATEGY}" != "Recreate" ]]; then
    echo "ERROR: Expected Deployment strategy Recreate."
    exit 1
fi

POD_COUNT="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l "${LABEL}" \
        --field-selector=status.phase=Running \
        --no-headers |
    wc -l
)"

if [[ "${POD_COUNT}" -ne 1 ]]; then
    echo "ERROR: Expected exactly one running Backend Pod."
    exit 1
fi

POD="$(
    kubectl get pods \
        -n "${K8S_NAMESPACE}" \
        -l "${LABEL}" \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}'
)"

SERVICE_TYPE="$(
    kubectl get service "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.spec.type}'
)"

SERVICE_PORT="$(
    kubectl get service "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.spec.ports[?(@.name=="http")].port}'
)"

CONTAINER_PORT="$(
    kubectl get deployment "${BACKEND_NAME}" \
        -n "${K8S_NAMESPACE}" \
        -o jsonpath='{.spec.template.spec.containers[0].ports[?(@.name=="http")].containerPort}'
)"

if [[ "${SERVICE_TYPE}" != "ClusterIP" ]]; then
    echo "ERROR: Backend Service is not ClusterIP."
    exit 1
fi

if [[ "${SERVICE_PORT}" != "${REST_PORT}" ]]; then
    echo "ERROR: Backend Service REST port mismatch."
    exit 1
fi

if [[ "${CONTAINER_PORT}" != "${REST_PORT}" ]]; then
    echo "ERROR: Backend container REST port mismatch."
    exit 1
fi

echo
echo "Backend Pod       : ${POD}"
echo "Deployment strategy: ${STRATEGY}"
echo "Service type      : ${SERVICE_TYPE}"
echo "REST port         : ${REST_PORT}"

echo
echo "============================================================"
echo " BACKEND VERIFY PASSED"
echo "============================================================"
