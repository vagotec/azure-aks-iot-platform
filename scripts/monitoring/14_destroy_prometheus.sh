#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " DESTROY - Prometheus"
echo "============================================================"

kubectl delete deployment \
  "${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true \
  --wait=true

kubectl delete service \
  "${PROMETHEUS_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true

kubectl delete configmap \
  "${PROMETHEUS_CONFIGMAP}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true

kubectl delete pvc \
  "${PROMETHEUS_PVC}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true \
  --wait=true


echo
echo "=== Wait until Prometheus Pods are completely gone ==="

for i in $(seq 1 60); do

  POD_COUNT="$(
    kubectl get pods \
      -n "${K8S_NAMESPACE}" \
      -l app.kubernetes.io/name=prometheus \
      --no-headers 2>/dev/null \
      | wc -l
  )"

  if [[ "${POD_COUNT}" -eq 0 ]]; then
    break
  fi

  sleep 1

done


POD_COUNT="$(
  kubectl get pods \
    -n "${K8S_NAMESPACE}" \
    -l app.kubernetes.io/name=prometheus \
    --no-headers 2>/dev/null \
    | wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
  echo "ERROR: Prometheus Pods still exist."
  exit 1
fi

echo "OK: Prometheus Pods removed."


echo
echo "=== Remove Prometheus image from K3s/containerd ==="

CANONICAL_IMAGE="${PROMETHEUS_IMAGE}"

if [[ "${CANONICAL_IMAGE}" != */*/* ]]; then
  CANONICAL_IMAGE="docker.io/${CANONICAL_IMAGE}"
fi

echo "Configured image : ${PROMETHEUS_IMAGE}"
echo "Canonical image  : ${CANONICAL_IMAGE}"

sudo k3s ctr -n k8s.io images remove \
  "${CANONICAL_IMAGE}" \
  2>/dev/null || true


echo
echo "=== Verify image removal inside DESTROY ==="

if sudo k3s ctr -n k8s.io images list \
  | awk '{print $1}' \
  | grep -Fxq "${CANONICAL_IMAGE}"; then

  echo "ERROR: Prometheus image still exists after removal."
  exit 1
fi

echo "OK: Prometheus image removed."


echo
echo "DESTROY PASSED"
