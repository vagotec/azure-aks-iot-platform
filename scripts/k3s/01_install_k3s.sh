#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo " Azure AKS IoT Platform"
echo " Phase 1.1 - Install K3s"
echo "========================================"
echo

# ------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------

if command -v k3s >/dev/null 2>&1; then
    echo "ERROR: K3s is already installed."
    echo "Existing installation will NOT be modified."
    k3s --version || true
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required but not installed."
    exit 1
fi

echo "Pre-flight checks: OK"
echo

# ------------------------------------------------------------
# Install K3s
#
# Traefik is deliberately disabled.
# Gateway API + Envoy Gateway will be installed separately.
# ------------------------------------------------------------

echo "Installing K3s without Traefik..."

curl -sfL https://get.k3s.io | sh -s - \
    --disable=traefik

echo
echo "K3s installation completed."
echo

# ------------------------------------------------------------
# Wait for K3s service
# ------------------------------------------------------------

echo "Waiting for K3s service..."

for i in {1..30}; do
    if sudo systemctl is-active --quiet k3s; then
        echo "K3s service is running."
        break
    fi

    if [[ "$i" -eq 30 ]]; then
        echo "ERROR: K3s service did not become active."
        sudo systemctl status k3s --no-pager || true
        exit 1
    fi

    sleep 2
done

echo

# ------------------------------------------------------------
# Basic verification
# ------------------------------------------------------------

echo "=== K3s Version ==="
sudo k3s --version

echo
echo "=== Kubernetes Nodes ==="
sudo k3s kubectl get nodes -o wide

echo
echo "=== Kubernetes System Pods ==="
sudo k3s kubectl get pods -A

echo
echo "========================================"
echo " Phase 1.1 completed successfully"
echo "========================================"
echo
echo "Traefik: DISABLED"
echo "Next step: configure kubectl for the user."
