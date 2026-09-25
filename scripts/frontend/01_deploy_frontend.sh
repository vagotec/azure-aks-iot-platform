#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/edge.env"
FRONTEND_DIR="${PROJECT_ROOT}/frontend/react-dashboard"
K8S_DIR="${FRONTEND_DIR}/kubernetes"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: Missing configuration: ${CONFIG_FILE}"
  exit 1
fi

set -a
source "${CONFIG_FILE}"
set +a

required_variables=(
  PROJECT_NAME
  K8S_NAMESPACE
  FRONTEND_IMAGE
  FRONTEND_NAME
  FRONTEND_PORT
  BACKEND_NAME
  REST_PORT
  GATEWAY_NAME
  GATEWAY_HTTP_LISTENER_NAME
  HTTPROUTE_NAME
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "ERROR: Required configuration variable is empty: ${variable}"
    exit 1
  fi
done

DEPLOYMENT_GENERATED="${K8S_DIR}/deployment.generated.yaml"
SERVICE_GENERATED="${K8S_DIR}/service.generated.yaml"
HTTPROUTE_GENERATED="${K8S_DIR}/httproute.generated.yaml"

echo "============================================================"
echo " DEPLOY - React Frontend"
echo "============================================================"

cd "${PROJECT_ROOT}"

echo
echo "=== Verify prerequisites ==="

kubectl get namespace "${K8S_NAMESPACE}" >/dev/null

kubectl wait \
  --for=condition=Accepted \
  gatewayclass/"${GATEWAY_NAME}" \
  --timeout=60s

kubectl wait \
  --for=condition=Programmed \
  gateway/"${GATEWAY_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=60s

kubectl rollout status \
  deployment/"${BACKEND_NAME}" \
  -n "${K8S_NAMESPACE}" \
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
echo "=== Render Kubernetes manifests from central configuration ==="

envsubst < "${K8S_DIR}/deployment.yaml.template" \
  > "${DEPLOYMENT_GENERATED}"

envsubst < "${K8S_DIR}/service.yaml.template" \
  > "${SERVICE_GENERATED}"

envsubst < "${K8S_DIR}/httproute.yaml.template" \
  > "${HTTPROUTE_GENERATED}"

echo
echo "=== Validate Kubernetes manifests ==="

kubectl apply \
  --dry-run=server \
  -f "${DEPLOYMENT_GENERATED}"

kubectl apply \
  --dry-run=server \
  -f "${SERVICE_GENERATED}"

kubectl apply \
  --dry-run=server \
  -f "${HTTPROUTE_GENERATED}"

echo
echo "=== Deploy Frontend Deployment and Service ==="

kubectl apply -f "${SERVICE_GENERATED}"
kubectl apply -f "${DEPLOYMENT_GENERATED}"

echo
echo "=== Wait for Frontend rollout ==="

kubectl rollout status \
  deployment/"${FRONTEND_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --timeout=180s

echo
echo "=== Deploy HTTPRoute ==="

kubectl apply -f "${HTTPROUTE_GENERATED}"

echo
echo "=== Wait for HTTPRoute acceptance ==="

ROUTE_ACCEPTED=false

for _ in $(seq 1 30); do
  ROUTE_STATUS="$(
    kubectl get httproute "${HTTPROUTE_NAME}" \
      -n "${K8S_NAMESPACE}" \
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
    -n "${K8S_NAMESPACE}" || true
  exit 1
fi

echo
echo "=== Verify HTTPRoute references ==="

RESOLVED_REFS="$(
  kubectl get httproute "${HTTPROUTE_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'
)"

if [[ "${RESOLVED_REFS}" != "True" ]]; then
  echo "ERROR: HTTPRoute backend references were not resolved."
  kubectl describe httproute \
    "${HTTPROUTE_NAME}" \
    -n "${K8S_NAMESPACE}"
  exit 1
fi

echo
echo "=== Gateway address ==="

GATEWAY_ADDRESS="$(
  kubectl get gateway "${GATEWAY_NAME}" \
    -n "${K8S_NAMESPACE}" \
    -o jsonpath='{.status.addresses[0].value}'
)"

echo "Gateway URL: http://${GATEWAY_ADDRESS}"

echo
echo "=== Frontend resources ==="

kubectl get deployment,service \
  -n "${K8S_NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  -o wide

kubectl get httproute \
  "${HTTPROUTE_NAME}" \
  -n "${K8S_NAMESPACE}" \
  -o wide

echo
echo "============================================================"
echo " FRONTEND DEPLOY PASSED"
echo "============================================================"
echo " URL: http://${GATEWAY_ADDRESS}"
echo "============================================================"
