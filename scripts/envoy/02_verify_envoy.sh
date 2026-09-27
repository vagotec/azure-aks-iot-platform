#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

ERRORS=0

echo "========================================"
echo " Verify Envoy Gateway Controller"
echo "========================================"

if helm status "${ENVOY_GATEWAY_RELEASE}" \
    --namespace "${ENVOY_GATEWAY_NAMESPACE}" >/dev/null 2>&1; then
    echo "OK: Helm release exists."
else
    echo "ERROR: Helm release not found."
    ERRORS=$((ERRORS + 1))
fi

if kubectl rollout status \
    deployment/envoy-gateway \
    --namespace "${ENVOY_GATEWAY_NAMESPACE}" \
    --timeout=60s; then
    echo "OK: Envoy Gateway controller available."
else
    echo "ERROR: Envoy Gateway controller unavailable."
    ERRORS=$((ERRORS + 1))
fi

if [[ "${ERRORS}" -ne 0 ]]; then
    echo "========================================"
    echo " Envoy Gateway verification FAILED"
    echo "========================================"
    exit 1
fi

echo "========================================"
echo " Envoy Gateway verification PASSED"
echo "========================================"
