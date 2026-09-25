#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="azure-aks-iot"
FRONTEND_NAME="azure-aks-iot-platform-frontend"
FRONTEND_IMAGE="azure-aks-iot-platform-frontend:local"
HTTPROUTE_NAME="azure-aks-iot-platform"
GATEWAY_NAME="azure-aks-iot-platform"
BACKEND_NAME="azure-aks-iot-platform-backend"

echo "============================================================"
echo " VERIFY DESTROY - React Frontend"
echo "============================================================"

echo
echo "=== Verify Frontend Kubernetes resources are absent ==="

if kubectl get deployment "${FRONTEND_NAME}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend Deployment still exists."
  exit 1
fi

if kubectl get service "${FRONTEND_NAME}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend Service still exists."
  exit 1
fi

if kubectl get httproute "${HTTPROUTE_NAME}" \
  -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend HTTPRoute still exists."
  exit 1
fi

if kubectl get pods \
  -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  --no-headers 2>/dev/null | grep -q .; then
  echo "ERROR: Frontend Pod still exists."
  exit 1
fi

echo "OK: Frontend Kubernetes resources are absent."

echo
echo "=== Verify Frontend images are absent ==="

K3S_IMAGE="docker.io/library/${FRONTEND_IMAGE}"

if sudo k3s ctr -n k8s.io images list | grep -Fq "${K3S_IMAGE}"; then
  echo "ERROR: Frontend image still exists in K3s."
  exit 1
fi

if docker image inspect "${FRONTEND_IMAGE}" >/dev/null 2>&1; then
  echo "ERROR: Frontend Docker image still exists."
  exit 1
fi

echo "OK: Frontend images are absent."

echo
echo "=== Verify shared platform remains intact ==="

kubectl get gateway "${GATEWAY_NAME}" \
  -n "${NAMESPACE}" >/dev/null

kubectl rollout status \
  deployment/"${BACKEND_NAME}" \
  -n "${NAMESPACE}" \
  --timeout=60s

GATEWAY_PROGRAMMED="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
)"

if [[ "${GATEWAY_PROGRAMMED}" != "True" ]]; then
  echo "ERROR: Shared Gateway is no longer Programmed."
  exit 1
fi

echo "OK: Envoy Gateway remains Programmed."
echo "OK: C++ Backend remains running."

echo
echo "============================================================"
echo " FRONTEND DESTROY VERIFICATION PASSED"
echo "============================================================"
