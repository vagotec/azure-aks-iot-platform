#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/config/edge.env"
TEMPLATE="${PROJECT_ROOT}/edge/mosquitto/kubernetes/mosquitto.yaml.template"
RENDERED="${PROJECT_ROOT}/edge/mosquitto/kubernetes/mosquitto.generated.yaml"

echo "========================================"
echo " Phase 2A.1 - Deploy Mosquitto"
echo "========================================"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: Missing ${ENV_FILE}"
    echo "Copy config/edge.env.example to config/edge.env first."
    exit 1
fi

command -v kubectl >/dev/null 2>&1 || {
    echo "ERROR: kubectl not found."
    exit 1
}

command -v envsubst >/dev/null 2>&1 || {
    echo "ERROR: envsubst not found."
    echo "Install the gettext-base package."
    exit 1
}

set -a
source "${ENV_FILE}"
set +a

kubectl get nodes >/dev/null

envsubst < "${TEMPLATE}" > "${RENDERED}"

echo
echo "Applying Mosquitto Kubernetes resources..."
kubectl apply -f "${RENDERED}"

echo
echo "Waiting for Mosquitto deployment..."
kubectl rollout status \
    deployment/"${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s

echo
echo "=== Mosquitto Pod ==="
kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=mosquitto \
    -o wide

echo
echo "=== Mosquitto Service ==="
kubectl get service "${MOSQUITTO_NAME}" \
    -n "${K8S_NAMESPACE}"

echo
echo "=== Mosquitto PVC ==="
kubectl get pvc "${MOSQUITTO_PVC}" \
    -n "${K8S_NAMESPACE}"

echo
echo "========================================"
echo " Phase 2A.1 completed successfully"
echo "========================================"
