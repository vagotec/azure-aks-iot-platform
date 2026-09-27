#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"
SECRETS_FILE="${PROJECT_ROOT}/config/secrets.env"

echo "============================================================"
echo " BOOTSTRAP LOCAL KUBERNETES SECRETS"
echo "============================================================"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing configuration: ${CONFIG_FILE}"
    exit 1
fi

if [[ ! -f "${SECRETS_FILE}" ]]; then
    echo "ERROR: Missing local secrets file: ${SECRETS_FILE}"
    echo "Create it from config/secrets.env.example."
    exit 1
fi

set -a
source "${CONFIG_FILE}"
source "${SECRETS_FILE}"
set +a

REQUIRED_VARS=(
    K8S_NAMESPACE
    GRAFANA_SECRET
    GRAFANA_ADMIN_PASSWORD
)

for VAR in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!VAR:-}" ]]; then
        echo "ERROR: ${VAR} is not configured."
        exit 1
    fi
done

if [[ "${GRAFANA_ADMIN_PASSWORD}" == "CHANGE_ME" ]]; then
    echo "ERROR: GRAFANA_ADMIN_PASSWORD still uses CHANGE_ME."
    exit 1
fi

echo "=== Wait for GitOps namespace ==="

kubectl wait \
    --for=jsonpath='{.status.phase}'=Active \
    namespace/"${K8S_NAMESPACE}" \
    --timeout=120s

echo "=== Create or update Grafana Kubernetes Secret ==="

kubectl create secret generic "${GRAFANA_SECRET}" \
    --namespace "${K8S_NAMESPACE}" \
    --from-literal=admin-password="${GRAFANA_ADMIN_PASSWORD}" \
    --dry-run=client \
    -o yaml |
kubectl apply -f -

echo "=== Verify Grafana Kubernetes Secret ==="

kubectl get secret "${GRAFANA_SECRET}" \
    --namespace "${K8S_NAMESPACE}" \
    >/dev/null

echo "OK: ${GRAFANA_SECRET} exists."
echo "LOCAL SECRET BOOTSTRAP PASSED"
