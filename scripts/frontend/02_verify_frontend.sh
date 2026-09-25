#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

echo "============================================================"
echo " VERIFY - React Frontend"
echo "============================================================"

kubectl rollout status \
  deployment/"${FRONTEND_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=120s

READY="$(
  kubectl get deployment "${FRONTEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.readyReplicas}'
)"

if [[ "${READY:-0}" != "1" ]]; then
  echo "ERROR: Frontend does not have exactly one ready replica."
  exit 1
fi

echo "OK: Frontend has exactly one ready replica."

SERVICE_PORT="$(
  kubectl get service "${FRONTEND_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.spec.ports[0].port}'
)"

if [[ "${SERVICE_PORT}" != "${FRONTEND_PORT}" ]]; then
  echo "ERROR: Expected Frontend Service port ${FRONTEND_PORT}, got ${SERVICE_PORT}."
  exit 1
fi

echo "OK: Frontend Service port is ${FRONTEND_PORT}."

ACCEPTED="$(
  kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
)"

RESOLVED="$(
  kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'
)"

if [[ "${ACCEPTED}" != "True" || "${RESOLVED}" != "True" ]]; then
  echo "ERROR: HTTPRoute Accepted=${ACCEPTED}, ResolvedRefs=${RESOLVED}"
  exit 1
fi

PROGRAMMED="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
)"

if [[ "${PROGRAMMED}" != "True" ]]; then
  echo "ERROR: Gateway Programmed=${PROGRAMMED}"
  exit 1
fi

GATEWAY_ADDRESS="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.addresses[0].value}'
)"

kubectl get pods \
  -n "${K8S_NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  -o wide

echo "Gateway URL: http://${GATEWAY_ADDRESS}"

echo "============================================================"
echo " FRONTEND VERIFY PASSED"
echo "============================================================"
