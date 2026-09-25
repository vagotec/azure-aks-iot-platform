#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAMESPACE="azure-aks-iot"
FRONTEND_NAME="azure-aks-iot-platform-frontend"
HTTPROUTE_NAME="azure-aks-iot-platform"
GATEWAY_NAME="azure-aks-iot-platform"

echo "============================================================"
echo " VERIFY - React Frontend"
echo "============================================================"

echo
echo "=== Deployment ==="

kubectl rollout status \
  deployment/"${FRONTEND_NAME}" \
  -n "${NAMESPACE}" \
  --timeout=120s

READY="$(
  kubectl get deployment "${FRONTEND_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY:-0}" != "1" ]]; then
  echo "ERROR: Frontend does not have exactly one ready replica."
  exit 1
fi

echo "OK: Frontend has exactly one ready replica."

echo
echo "=== Frontend Service ==="

SERVICE_PORT="$(
  kubectl get service "${FRONTEND_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.ports[0].port}'
)"

if [[ "${SERVICE_PORT}" != "8080" ]]; then
  echo "ERROR: Expected Frontend Service port 8080, got ${SERVICE_PORT}."
  exit 1
fi

echo "OK: Frontend Service port is 8080."

echo
echo "=== HTTPRoute ==="

ACCEPTED="$(
  kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
)"

RESOLVED="$(
  kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'
)"

if [[ "${ACCEPTED}" != "True" ]]; then
  echo "ERROR: HTTPRoute Accepted=${ACCEPTED}"
  exit 1
fi

if [[ "${RESOLVED}" != "True" ]]; then
  echo "ERROR: HTTPRoute ResolvedRefs=${RESOLVED}"
  exit 1
fi

echo "OK: HTTPRoute Accepted=True."
echo "OK: HTTPRoute ResolvedRefs=True."

echo
echo "=== Gateway ==="

PROGRAMMED="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
)"

if [[ "${PROGRAMMED}" != "True" ]]; then
  echo "ERROR: Gateway Programmed=${PROGRAMMED}"
  exit 1
fi

GATEWAY_ADDRESS="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.addresses[0].value}'
)"

echo "OK: Gateway Programmed=True."
echo "Gateway URL: http://${GATEWAY_ADDRESS}"

echo
echo "=== Frontend Pod ==="

kubectl get pods \
  -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  -o wide

echo
echo "============================================================"
echo " FRONTEND VERIFY PASSED"
echo "============================================================"
