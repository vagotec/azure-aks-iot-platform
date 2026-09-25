#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo " Azure AKS IoT Platform"
echo " Phase 1.3 - Verify K3s"
echo "========================================"
echo

ERRORS=0

# ------------------------------------------------------------
# 1. K3s service
# ------------------------------------------------------------

echo "=== K3s Service ==="

if sudo systemctl is-active --quiet k3s; then
    echo "OK: K3s service is running."
else
    echo "ERROR: K3s service is not running."
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------
# 2. Kubernetes node
# ------------------------------------------------------------

echo
echo "=== Kubernetes Node ==="

kubectl get nodes -o wide

NOT_READY="$(
    kubectl get nodes \
        --no-headers \
        2>/dev/null \
        | awk '$2 != "Ready" {print $1}'
)"

if [[ -z "${NOT_READY}" ]]; then
    echo "OK: All Kubernetes nodes are Ready."
else
    echo "ERROR: Nodes not Ready:"
    echo "${NOT_READY}"
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------
# 3. Kubernetes system pods
# ------------------------------------------------------------

echo
echo "=== Kubernetes System Pods ==="

kubectl get pods -n kube-system

BAD_PODS="$(
    kubectl get pods -n kube-system \
        --no-headers \
        2>/dev/null \
        | awk '$3 != "Running" && $3 != "Completed" {print $1 " -> " $3}'
)"

if [[ -z "${BAD_PODS}" ]]; then
    echo "OK: All kube-system pods are healthy."
else
    echo "ERROR: Unhealthy kube-system pods:"
    echo "${BAD_PODS}"
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------
# 4. Traefik must not be installed
# ------------------------------------------------------------

echo
echo "=== Traefik ==="

if kubectl get pods -A --no-headers 2>/dev/null | grep -qi traefik; then
    echo "ERROR: Traefik pod detected."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Traefik is not running."
fi

# ------------------------------------------------------------
# Result
# ------------------------------------------------------------

echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " K3s verification PASSED"
    echo "========================================"
    echo
    echo "K3s base platform is ready."
    exit 0
else
    echo " K3s verification FAILED"
    echo " Errors: ${ERRORS}"
    echo "========================================"
    exit 1
fi
