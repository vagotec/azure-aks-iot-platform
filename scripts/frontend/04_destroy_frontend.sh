#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

NAMESPACE="azure-aks-iot"
FRONTEND_NAME="azure-aks-iot-platform-frontend"
FRONTEND_IMAGE="azure-aks-iot-platform-frontend:local"
HTTPROUTE_NAME="azure-aks-iot-platform"

echo "============================================================"
echo " DESTROY - React Frontend"
echo "============================================================"

echo
echo "=== Delete HTTPRoute ==="

kubectl delete httproute "${HTTPROUTE_NAME}" \
  -n "${NAMESPACE}" \
  --ignore-not-found=true

echo
echo "=== Delete Frontend Deployment and Service ==="

kubectl delete deployment "${FRONTEND_NAME}" \
  -n "${NAMESPACE}" \
  --ignore-not-found=true

kubectl delete service "${FRONTEND_NAME}" \
  -n "${NAMESPACE}" \
  --ignore-not-found=true

echo
echo "=== Wait until Frontend Pods are gone ==="

while kubectl get pods \
  -n "${NAMESPACE}" \
  -l app.kubernetes.io/name=frontend \
  --no-headers 2>/dev/null | grep -q .; do

  echo "Waiting for Frontend Pod deletion..."
  sleep 2
done

echo "OK: Frontend Pods removed."

echo
echo "=== Remove Frontend image from K3s containerd ==="

K3S_IMAGE="docker.io/library/${FRONTEND_IMAGE}"

if sudo k3s ctr -n k8s.io images list | grep -Fq "${K3S_IMAGE}"; then
  sudo k3s ctr -n k8s.io images rm "${K3S_IMAGE}"
else
  echo "K3s Frontend image already absent."
fi

echo
echo "=== Remove local Docker image ==="

if docker image inspect "${FRONTEND_IMAGE}" >/dev/null 2>&1; then
  docker image rm "${FRONTEND_IMAGE}"
else
  echo "Docker Frontend image already absent."
fi

echo
echo "============================================================"
echo " FRONTEND DESTROY PASSED"
echo "============================================================"
