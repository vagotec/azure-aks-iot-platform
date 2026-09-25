#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Phase 1.7 - Destroy Project K3s"
echo "========================================"

echo
echo "Current project cluster:"
kubectl get nodes 2>/dev/null || true
kubectl get pods -A 2>/dev/null || true

echo
echo "Destroying complete K3s cluster..."

if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    sudo /usr/local/bin/k3s-uninstall.sh
else
    echo "ERROR: K3s uninstall script not found."
    exit 1
fi

# This kubeconfig belongs to this project K3s cluster.
if [[ -f "${HOME}/.kube/config" ]]; then
    echo "Removing project K3s kubeconfig..."
    rm -f "${HOME}/.kube/config"
fi

echo
echo "Project K3s cluster destroyed."
