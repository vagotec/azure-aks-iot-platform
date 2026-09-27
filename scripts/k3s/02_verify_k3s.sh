#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/k3s.env"
STATE_DIR="${PROJECT_ROOT}/.state/k3s"

echo "============================================================"
echo " VERIFY K3S"
echo "============================================================"

ERRORS=0

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing ${CONFIG_FILE}"
    exit 1
fi

if [[ ! -f "${STATE_DIR}/resolved.env" ]]; then
    echo "ERROR: Missing deployment state."
    exit 1
fi

if [[ ! -f "${STATE_DIR}/kubeconfig" ]]; then
    echo "ERROR: Missing project kubeconfig."
    exit 1
fi

set -a
source "${CONFIG_FILE}"
source "${STATE_DIR}/resolved.env"
set +a

export KUBECONFIG="${STATE_DIR}/kubeconfig"

echo
echo "=== K3s service ==="

if sudo systemctl is-active --quiet k3s; then
    echo "OK: k3s.service is active."
else
    echo "ERROR: k3s.service is not active."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "=== Host network ==="

CURRENT_IP="$(
    ip -4 -o addr show dev "${K3S_NETWORK_INTERFACE}" scope global |
    awk '{split($4,a,"/"); print a[1]; exit}'
)"

echo "Interface          : ${K3S_NETWORK_INTERFACE}"
echo "Current host IP    : ${CURRENT_IP:-NOT_FOUND}"
echo "Deployment node IP : ${K3S_RESOLVED_NODE_IP}"

if [[ "${CURRENT_IP:-}" != "${K3S_RESOLVED_NODE_IP}" ]]; then
    echo "ERROR: Host IP changed since K3s deployment."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Host IP matches deployment configuration."
fi

echo
echo "=== Kubernetes node ==="

kubectl get nodes -o wide

NODE_COUNT="$(kubectl get nodes --no-headers | wc -l)"

if [[ "${NODE_COUNT}" -ne 1 ]]; then
    echo "ERROR: Expected exactly one local K3s node."
    ERRORS=$((ERRORS + 1))
fi

NODE_IP="$(
    kubectl get nodes \
        -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}'
)"

NODE_READY="$(
    kubectl get nodes \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'
)"

echo "Kubernetes InternalIP: ${NODE_IP}"
echo "Kubernetes Ready     : ${NODE_READY}"

if [[ "${NODE_IP}" != "${K3S_RESOLVED_NODE_IP}" ]]; then
    echo "ERROR: Kubernetes InternalIP does not match configured node IP."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Kubernetes InternalIP matches."
fi

if [[ "${NODE_READY}" != "True" ]]; then
    echo "ERROR: Kubernetes node is not Ready."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "=== Kubernetes API EndpointSlice ==="

kubectl get endpointslice \
    -n default \
    -l kubernetes.io/service-name=kubernetes \
    -o wide

API_ENDPOINT_RAW="$(
    kubectl get endpointslice \
        -n default \
        -l kubernetes.io/service-name=kubernetes \
        -o jsonpath='{.items[*].endpoints[*].addresses[*]}'
)"

read -r -a API_ENDPOINT_IPS <<< "${API_ENDPOINT_RAW}"

printf 'API endpoint IPs:'
printf ' %s' "${API_ENDPOINT_IPS[@]:-}"
printf '\n'

if [[ "${#API_ENDPOINT_IPS[@]}" -ne 1 ]] ||
   [[ "${API_ENDPOINT_IPS[0]:-}" != "${K3S_RESOLVED_NODE_IP}" ]]; then
    echo "ERROR: Kubernetes API endpoint does not exactly match node IP."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Kubernetes API endpoint matches node IP."
fi

echo
echo "=== kube-system pods ==="

kubectl get pods -n kube-system

BAD_PODS="$(
    kubectl get pods -n kube-system --no-headers |
    awk '
        $3 != "Running" &&
        $3 != "Completed" &&
        $3 != "Succeeded" {
            print $1 " -> " $3
        }
    '
)"

if [[ -n "${BAD_PODS}" ]]; then
    echo "ERROR: Unhealthy kube-system pods:"
    echo "${BAD_PODS}"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: kube-system pod phases are healthy."
fi

NOT_READY_PODS="$(
    kubectl get pods -n kube-system \
        -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.containerStatuses[*]}{.ready}{" "}{end}{"\n"}{end}' |
    awk '$0 ~ /false/ {print}'
)"

if [[ -n "${NOT_READY_PODS}" ]]; then
    echo "ERROR: kube-system contains non-ready containers:"
    echo "${NOT_READY_PODS}"
    ERRORS=$((ERRORS + 1))
else
    echo "OK: kube-system containers are Ready."
fi

echo
echo "=== Traefik ==="

if kubectl get pods -A --no-headers | grep -qi traefik; then
    echo "ERROR: Traefik is running."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Traefik is disabled."
fi

echo
echo "============================================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " K3S VERIFICATION PASSED"
    echo "============================================================"
    exit 0
fi

echo " K3S VERIFICATION FAILED"
echo " Errors: ${ERRORS}"
echo "============================================================"
exit 1
