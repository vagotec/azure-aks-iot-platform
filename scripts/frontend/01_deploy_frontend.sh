#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FRONTEND_DIR="${PROJECT_ROOT}/frontend/react-dashboard"

NAMESPACE="azure-aks-iot"

FRONTEND_NAME="azure-aks-iot-platform-frontend"
FRONTEND_IMAGE="azure-aks-iot-platform-frontend:local"

BACKEND_NAME="azure-aks-iot-platform-backend"

GATEWAY_NAME="azure-aks-iot-platform"
HTTPROUTE_NAME="azure-aks-iot-platform"

echo "============================================================"
echo " DEPLOY - React Frontend"
echo "============================================================"

cd "${PROJECT_ROOT}"

echo
echo "=== Verify prerequisites ==="

kubectl get namespace "${NAMESPACE}" >/dev/null

kubectl wait \
  --for=condition=Accepted \
  gatewayclass/"${GATEWAY_NAME}" \
  --timeout=60s

kubectl wait \
  --for=condition=Programmed \
  gateway/"${GATEWAY_NAME}" \
  -n "${NAMESPACE}" \
  --timeout=60s

kubectl rollout status \
  deployment/"${BACKEND_NAME}" \
  -n "${NAMESPACE}" \
  --timeout=120s

echo
echo "=== Node toolchain ==="

cd "${FRONTEND_DIR}"

echo "Node : $(node --version)"
echo "npm  : $(npm --version)"

echo
echo "=== Install locked Frontend dependencies ==="

npm ci

echo
echo "=== Production TypeScript / Vite build ==="

npm run build

echo
echo "=== Build Frontend container image ==="

docker build \
  --file Containerfile \
  --tag "${FRONTEND_IMAGE}" \
  .

echo
echo "=== Export Frontend image ==="

IMAGE_ARCHIVE="$(mktemp --suffix=.tar)"

cleanup() {
  rm -f "${IMAGE_ARCHIVE}"
}

trap cleanup EXIT

docker save \
  "${FRONTEND_IMAGE}" \
  --output "${IMAGE_ARCHIVE}"

echo
echo "=== Import Frontend image into K3s containerd ==="

sudo k3s ctr -n k8s.io images import "${IMAGE_ARCHIVE}"

echo
echo "=== Verify imported K3s image ==="

sudo k3s ctr -n k8s.io images list |
  grep -F "docker.io/library/${FRONTEND_IMAGE}"

echo
echo "=== Validate Kubernetes manifests ==="

cd "${PROJECT_ROOT}"

kubectl apply \
  --dry-run=server \
  -f frontend/react-dashboard/kubernetes/deployment.yaml

kubectl apply \
  --dry-run=server \
  -f frontend/react-dashboard/kubernetes/service.yaml

kubectl apply \
  --dry-run=server \
  -f frontend/react-dashboard/kubernetes/httproute.yaml

echo
echo "=== Deploy Frontend Deployment and Service ==="

kubectl apply \
  -f frontend/react-dashboard/kubernetes/service.yaml

kubectl apply \
  -f frontend/react-dashboard/kubernetes/deployment.yaml

echo
echo "=== Wait for Frontend rollout ==="

kubectl rollout status \
  deployment/"${FRONTEND_NAME}" \
  -n "${NAMESPACE}" \
  --timeout=180s

echo
echo "=== Deploy HTTPRoute ==="

kubectl apply \
  -f frontend/react-dashboard/kubernetes/httproute.yaml

echo
echo "=== Wait for HTTPRoute acceptance ==="

ROUTE_ACCEPTED=false

for _ in $(seq 1 30); do
  ROUTE_STATUS="$(
    kubectl get httproute "${HTTPROUTE_NAME}" \
      -n "${NAMESPACE}" \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' \
      2>/dev/null || true
  )"

  if [[ "${ROUTE_STATUS}" == "True" ]]; then
    ROUTE_ACCEPTED=true
    break
  fi

  sleep 1
done

if [[ "${ROUTE_ACCEPTED}" != "true" ]]; then
  echo "ERROR: HTTPRoute was not accepted."
  kubectl describe httproute \
    "${HTTPROUTE_NAME}" \
    -n "${NAMESPACE}" || true
  exit 1
fi

echo
echo "=== Verify HTTPRoute references ==="

RESOLVED_REFS="$(
  kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'
)"

if [[ "${RESOLVED_REFS}" != "True" ]]; then
  echo "ERROR: HTTPRoute backend references were not resolved."
  kubectl describe httproute \
    "${HTTPROUTE_NAME}" \
    -n "${NAMESPACE}"
  exit 1
fi

echo
echo "=== Gateway address ==="

GATEWAY_ADDRESS="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.status.addresses[0].value}'
)"

echo "Gateway URL: http://${GATEWAY_ADDRESS}"

echo
echo "=== Frontend resources ==="

kubectl get deployment,service \
  -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  -o wide

kubectl get httproute \
  "${HTTPROUTE_NAME}" \
  -n "${NAMESPACE}" \
  -o wide

echo
echo "============================================================"
echo " FRONTEND DEPLOY PASSED"
echo "============================================================"
echo " URL: http://${GATEWAY_ADDRESS}"
echo "============================================================"
