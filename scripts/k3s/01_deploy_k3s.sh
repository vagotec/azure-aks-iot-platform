#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/k3s.env"
STATE_DIR="${PROJECT_ROOT}/.state/k3s"
K3S_CONFIG="/etc/rancher/k3s/config.yaml"

echo "============================================================"
echo " DEPLOY K3S"
echo "============================================================"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Missing ${CONFIG_FILE}"
    echo "Create it from config/k3s.env.example."
    exit 1
fi

set -a
source "${CONFIG_FILE}"
set +a

required_variables=(
    K3S_VERSION
    K3S_NODE_NAME
    K3S_NETWORK_INTERFACE
    K3S_NODE_IP
    K3S_CLUSTER_CIDR
    K3S_SERVICE_CIDR
    K3S_DISABLE_TRAEFIK
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        echo "ERROR: Required variable is empty: ${variable}"
        exit 1
    fi
done

for command in curl ip awk grep; do
    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: ${command}"
        exit 1
    fi
done

if ! ip link show "${K3S_NETWORK_INTERFACE}" >/dev/null 2>&1; then
    echo "ERROR: Network interface does not exist:"
    echo "       ${K3S_NETWORK_INTERFACE}"
    exit 1
fi

if [[ "${K3S_NODE_IP}" == "auto" ]]; then
    RESOLVED_NODE_IP="$(
        ip -4 -o addr show dev "${K3S_NETWORK_INTERFACE}" scope global |
        awk '{split($4,a,"/"); print a[1]; exit}'
    )"
else
    RESOLVED_NODE_IP="${K3S_NODE_IP}"
fi

if [[ -z "${RESOLVED_NODE_IP}" ]]; then
    echo "ERROR: Could not resolve IPv4 address for:"
    echo "       ${K3S_NETWORK_INTERFACE}"
    exit 1
fi

if ! ip -4 -o addr show dev "${K3S_NETWORK_INTERFACE}" |
     awk '{split($4,a,"/"); print a[1]}' |
     grep -Fxq "${RESOLVED_NODE_IP}"; then
    echo "ERROR: Configured node IP is not assigned to"
    echo "       ${K3S_NETWORK_INTERFACE}: ${RESOLVED_NODE_IP}"
    exit 1
fi

if command -v k3s >/dev/null 2>&1; then
    echo "ERROR: K3s is already installed."
    echo "Use the lifecycle scripts instead of modifying it in place."
    exit 1
fi

mkdir -p "${STATE_DIR}"

cat > "${STATE_DIR}/resolved.env" <<STATE
K3S_RESOLVED_NODE_IP=${RESOLVED_NODE_IP}
K3S_RESOLVED_INTERFACE=${K3S_NETWORK_INTERFACE}
STATE

echo
echo "Node name       : ${K3S_NODE_NAME}"
echo "Network interface: ${K3S_NETWORK_INTERFACE}"
echo "Resolved node IP : ${RESOLVED_NODE_IP}"
echo "Cluster CIDR     : ${K3S_CLUSTER_CIDR}"
echo "Service CIDR     : ${K3S_SERVICE_CIDR}"
echo "K3s version      : ${K3S_VERSION}"

echo
echo "=== Create persistent K3s configuration ==="

sudo install -d -m 0755 /etc/rancher/k3s

DISABLE_BLOCK=""
if [[ "${K3S_DISABLE_TRAEFIK}" == "true" ]]; then
    DISABLE_BLOCK=$'disable:\n  - traefik'
fi

cat > "${STATE_DIR}/config.yaml" <<CONFIG
node-name: "${K3S_NODE_NAME}"
node-ip: "${RESOLVED_NODE_IP}"
advertise-address: "${RESOLVED_NODE_IP}"
flannel-iface: "${K3S_NETWORK_INTERFACE}"
cluster-cidr: "${K3S_CLUSTER_CIDR}"
service-cidr: "${K3S_SERVICE_CIDR}"
${DISABLE_BLOCK}
CONFIG

sudo install \
    -m 0600 \
    "${STATE_DIR}/config.yaml" \
    "${K3S_CONFIG}"

echo
echo "=== Install K3s ==="

curl -sfL https://get.k3s.io |
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    INSTALL_K3S_EXEC="server" \
    sh -

echo
echo "=== Wait for K3s service ==="

for i in $(seq 1 60); do
    if sudo systemctl is-active --quiet k3s; then
        break
    fi

    if [[ "${i}" -eq 60 ]]; then
        echo "ERROR: K3s service did not become active."
        sudo systemctl status k3s --no-pager || true
        exit 1
    fi

    sleep 2
done

echo
echo "=== Create project-owned kubeconfig ==="

sudo cp /etc/rancher/k3s/k3s.yaml "${STATE_DIR}/kubeconfig"
sudo chown "$(id -u):$(id -g)" "${STATE_DIR}/kubeconfig"
chmod 600 "${STATE_DIR}/kubeconfig"

export KUBECONFIG="${STATE_DIR}/kubeconfig"

echo
echo "=== Wait for Kubernetes API ==="

for i in $(seq 1 60); do
    if kubectl get nodes >/dev/null 2>&1; then
        break
    fi

    if [[ "${i}" -eq 60 ]]; then
        echo "ERROR: Kubernetes API did not become reachable."
        sudo journalctl -u k3s -n 100 --no-pager || true
        exit 1
    fi

    sleep 2
done

kubectl get nodes -o wide

echo
echo "============================================================"
echo " K3S DEPLOYED"
echo "============================================================"
echo
echo "Project kubeconfig:"
echo "  ${STATE_DIR}/kubeconfig"
