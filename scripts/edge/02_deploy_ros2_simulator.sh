#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENV_FILE="${PROJECT_ROOT}/config/edge.env"
TEMPLATE="${PROJECT_ROOT}/edge/ros2-simulator/kubernetes/deployment.yaml.template"
RENDERED="${PROJECT_ROOT}/edge/ros2-simulator/kubernetes/deployment.generated.yaml"

set -a
source "${ENV_FILE}"
set +a

echo "========================================"
echo " Phase 2B.2 - Deploy ROS 2 Simulator"
echo "========================================"

command -v envsubst >/dev/null 2>&1 || {
    echo "ERROR: envsubst not found."
    exit 1
}

kubectl get namespace "${K8S_NAMESPACE}" >/dev/null

envsubst < "${TEMPLATE}" > "${RENDERED}"

kubectl apply -f "${RENDERED}"

echo
echo "Waiting for deployment..."

kubectl rollout status \
    deployment/"${ROS2_SIMULATOR_NAME}" \
    -n "${K8S_NAMESPACE}" \
    --timeout=120s

echo
kubectl get pod \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=ros2-simulator \
    -o wide

echo
echo "========================================"
echo " Phase 2B.2 completed successfully"
echo "========================================"
