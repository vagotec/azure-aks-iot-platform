#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " DESTROY - Grafana"
echo "============================================================"

kubectl delete deployment \
  "${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true \
  --wait=true

kubectl delete service \
  "${GRAFANA_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true

kubectl delete configmap \
  "${GRAFANA_PROVISIONING_CONFIGMAP}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true

kubectl delete secret \
  "${GRAFANA_SECRET}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true

kubectl delete pvc \
  "${GRAFANA_PVC}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true \
  --wait=true

echo
echo "=== Wait until Grafana Pods are completely gone ==="

for ATTEMPT in $(seq 1 60); do
  POD_COUNT="$(
    kubectl get pods \
      -n "${K8S_NAMESPACE}" \
      -l app.kubernetes.io/name=grafana \
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
    -l app.kubernetes.io/name=grafana \
    --no-headers 2>/dev/null \
    | wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
  echo "ERROR: Grafana Pods still exist."
  exit 1
fi

echo "OK: Grafana Pods removed."

echo
echo "=== Remove Grafana image from K3s/containerd ==="

CANONICAL_IMAGE="${GRAFANA_IMAGE}"

if [[ "${CANONICAL_IMAGE}" != */*/* ]]; then
  CANONICAL_IMAGE="docker.io/${CANONICAL_IMAGE}"
fi

echo "Configured image : ${GRAFANA_IMAGE}"
echo "Canonical image  : ${CANONICAL_IMAGE}"

sudo k3s ctr -n k8s.io images remove \
  "${CANONICAL_IMAGE}" \
  2>/dev/null || true

echo
echo "=== Verify image removal inside DESTROY ==="

if grep -Fxq "${CANONICAL_IMAGE}" < <(
  sudo k3s ctr -n k8s.io images list |
    awk '{print $1}'
); then
  echo "ERROR: Grafana image still exists after removal."
  exit 1
fi

echo "OK: Grafana image removed."

echo
echo "DESTROY PASSED"
