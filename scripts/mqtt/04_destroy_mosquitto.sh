#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/config/edge.env"
RENDERED="${PROJECT_ROOT}/edge/mosquitto/kubernetes/mosquitto.generated.yaml"

echo "========================================"
echo " Phase 2A.4 - Destroy Mosquitto"
echo "========================================"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "ERROR: Missing ${ENV_FILE}"
    exit 1
fi

set -a
source "${ENV_FILE}"
set +a

echo
echo "=== Project configuration ==="
echo "Namespace: ${K8S_NAMESPACE}"
echo "Mosquitto: ${MOSQUITTO_NAME}"
echo "Image:     ${MOSQUITTO_IMAGE}"

echo
echo "=== Delete Mosquitto Kubernetes resources ==="

if [[ -f "${RENDERED}" ]]; then
    kubectl delete -f "${RENDERED}" \
        --ignore-not-found=true \
        --wait=true
else
    echo "Generated manifest not found."
    echo "Deleting known project resources individually."

    kubectl delete deployment "${MOSQUITTO_NAME}" \
        -n "${K8S_NAMESPACE}" \
        --ignore-not-found=true \
        --wait=true

    kubectl delete service "${MOSQUITTO_NAME}" \
        -n "${K8S_NAMESPACE}" \
        --ignore-not-found=true

    kubectl delete configmap "${MOSQUITTO_CONFIGMAP}" \
        -n "${K8S_NAMESPACE}" \
        --ignore-not-found=true

    kubectl delete pvc "${MOSQUITTO_PVC}" \
        -n "${K8S_NAMESPACE}" \
        --ignore-not-found=true \
        --wait=true
fi

echo
echo "=== Preserve shared project namespace ==="
echo "Namespace ${K8S_NAMESPACE} is shared and is not owned by Mosquitto."

echo
echo "=== Remove generated manifest ==="
rm -f "${RENDERED}"

echo
echo "=== K3s image before removal ==="
sudo k3s ctr images list \
    | grep -F "${MOSQUITTO_IMAGE}" || true

echo
echo "=== Remove configured Mosquitto image from K3s containerd ==="

IMAGE_REF="docker.io/library/${MOSQUITTO_IMAGE}"

if grep -Fxq "${IMAGE_REF}" < <(
    sudo k3s ctr images list -q
); then
    sudo k3s ctr images remove "${IMAGE_REF}"
    echo "Removed: ${IMAGE_REF}"
else
    echo "Image reference not present: ${IMAGE_REF}"
fi

echo
echo "========================================"
echo " Phase 2A.4 destroy completed"
echo "========================================"
