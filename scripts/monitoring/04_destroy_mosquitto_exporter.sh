#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

source "${PROJECT_ROOT}/config/edge.env"

echo "============================================================"
echo " DESTROY - Mosquitto Exporter"
echo "============================================================"

kubectl delete deployment \
  "${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true \
  --wait=true

kubectl delete service \
  "${MOSQUITTO_EXPORTER_NAME}" \
  -n "${K8S_NAMESPACE}" \
  --ignore-not-found=true

echo
echo "=== Wait until exporter Pods are completely gone ==="

for i in $(seq 1 60); do

  POD_COUNT="$(
    kubectl get pods \
      -n "${K8S_NAMESPACE}" \
      -l app.kubernetes.io/name=mosquitto-exporter \
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
    -l app.kubernetes.io/name=mosquitto-exporter \
    --no-headers 2>/dev/null \
    | wc -l
)"

if [[ "${POD_COUNT}" -ne 0 ]]; then
  echo "ERROR: Mosquitto Exporter Pods still exist."
  exit 1
fi

echo "OK: Exporter Pods removed."

echo
echo "=== Remove exporter image from K3s/containerd ==="

sudo k3s ctr -n k8s.io images remove \
  "${MOSQUITTO_EXPORTER_IMAGE}" \
  2>/dev/null || true

echo
echo "DESTROY PASSED"
