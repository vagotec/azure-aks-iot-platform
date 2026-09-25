#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"

set -a
source "${CONFIG_FILE}"
set +a

echo "============================================================"
echo " VERIFY DESTROY - React Frontend"
echo "============================================================"

if kubectl get deployment "${FRONTEND_NAME}" \
  -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend Deployment still exists."
  exit 1
fi

if kubectl get service "${FRONTEND_NAME}" \
  -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend Service still exists."
  exit 1
fi

if kubectl get httproute "${HTTPROUTE_NAME}" \
  -n "${K8S_NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend HTTPRoute still exists."
  exit 1
fi

if kubectl get pods \
  -n "${K8S_NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  --no-headers 2>/dev/null | grep -q .; then
  echo "ERROR: Frontend Pod still exists."
  exit 1
fi

echo "OK: Frontend Kubernetes resources are absent."

K3S_IMAGE="docker.io/library/${FRONTEND_IMAGE}"

if grep -Fq "${K3S_IMAGE}" < <(
  sudo k3s ctr -n k8s.io images list
); then
  echo "ERROR: Frontend image still exists in K3s."
  exit 1
fi

if docker image inspect "${FRONTEND_IMAGE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend Docker image still exists."
  exit 1
fi

echo "OK: Frontend images are absent."

kubectl get gateway "${GATEWAY_NAME}" \
  -n "${K8S_NAMESPACE}" >/dev/null

kubectl rollout status \
  deployment/"${BACKEND_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

GATEWAY_PROGRAMMED="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
)"

if [[ "${GATEWAY_PROGRAMMED}" != "True" ]]; then
  echo "ERROR: Shared Gateway is no longer Programmed."
  exit 1
fi

echo "OK: Envoy Gateway remains Programmed."
echo "OK: C++ Backend remains running."

echo "============================================================"
echo " FRONTEND DESTROY VERIFICATION PASSED"
echo "============================================================"
