#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

echo "========================================"
echo " Test Envoy Gateway Controller"
echo "========================================"

AVAILABLE="$(
    kubectl get deployment envoy-gateway \
        --namespace "${ENVOY_GATEWAY_NAMESPACE}" \
        -o jsonpath='{.status.availableReplicas}'
)"

if [[ -z "${AVAILABLE}" || "${AVAILABLE}" -lt 1 ]]; then
    echo "ERROR: Envoy Gateway has no available controller replica."
    exit 1
fi

echo "OK: Envoy Gateway controller has ${AVAILABLE} available replica(s)."

echo "========================================"
echo " Envoy Gateway functional test PASSED"
echo "========================================"
