#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo " Azure AKS IoT Platform"
echo " Phase 1.2 - Configure kubectl"
echo "========================================"
echo

K3S_KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
USER_KUBE_DIR="${HOME}/.kube"
USER_KUBECONFIG="${USER_KUBE_DIR}/config"

# ------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------

if ! sudo test -f "${K3S_KUBECONFIG}"; then
    echo "ERROR: K3s kubeconfig not found:"
    echo "       ${K3S_KUBECONFIG}"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "ERROR: kubectl is not installed."
    exit 1
fi

echo "Pre-flight checks: OK"
echo

# ------------------------------------------------------------
# Protect an existing user kubeconfig
# ------------------------------------------------------------

mkdir -p "${USER_KUBE_DIR}"

if [[ -f "${USER_KUBECONFIG}" ]]; then
    BACKUP="${USER_KUBECONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

    echo "Existing kubeconfig detected."
    echo "Creating backup:"
    echo "  ${BACKUP}"

    cp "${USER_KUBECONFIG}" "${BACKUP}"
fi

# ------------------------------------------------------------
# Install K3s kubeconfig for current user
# ------------------------------------------------------------

echo "Installing K3s kubeconfig for user: ${USER}"

sudo cp "${K3S_KUBECONFIG}" "${USER_KUBECONFIG}"
sudo chown "${USER}:${USER}" "${USER_KUBECONFIG}"
chmod 600 "${USER_KUBECONFIG}"

echo
echo "Kubeconfig installed:"
echo "  ${USER_KUBECONFIG}"

# ------------------------------------------------------------
# Wait for node registration
# ------------------------------------------------------------

echo
echo "Waiting for K3s node registration..."

for i in {1..30}; do
    NODE_COUNT="$(kubectl get nodes --no-headers 2>/dev/null | wc -l)"

    if [[ "${NODE_COUNT}" -ge 1 ]]; then
        echo "Node registered."
        break
    fi

    if [[ "${i}" -eq 30 ]]; then
        echo
        echo "ERROR: No Kubernetes node registered after 60 seconds."
        echo
        echo "K3s service status:"
        sudo systemctl status k3s --no-pager || true
        echo
        echo "Recent K3s logs:"
        sudo journalctl -u k3s -n 50 --no-pager || true
        exit 1
    fi

    sleep 2
done

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------

echo
echo "=== kubectl Context ==="
kubectl config current-context

echo
echo "=== Kubernetes Nodes ==="
kubectl get nodes -o wide

echo
echo "=== Kubernetes Pods ==="
kubectl get pods -A

echo
echo "=== Traefik Check ==="

if kubectl get pods -A --no-headers 2>/dev/null | grep -qi traefik; then
    echo "ERROR: Traefik is running but should be disabled."
    exit 1
else
    echo "Traefik: NOT INSTALLED - OK"
fi

echo
echo "========================================"
echo " Phase 1.2 completed successfully"
echo "========================================"
