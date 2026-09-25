#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Phase 1.8 - Verify Destroy"
echo "========================================"

ERRORS=0

echo
echo "=== K3s binary ==="
if command -v k3s >/dev/null 2>&1; then
    echo "ERROR: K3s still installed."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: K3s binary removed."
fi

echo
echo "=== K3s service ==="
if systemctl list-unit-files --no-legend 2>/dev/null \
    | awk '{print $1}' | grep -qx 'k3s.service'; then
    echo "ERROR: k3s.service still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: K3s service removed."
fi

echo
echo "=== K3s cluster data ==="
for path in \
    /etc/rancher/k3s \
    /var/lib/rancher/k3s
do
    if sudo test -e "${path}"; then
        echo "ERROR: Still exists: ${path}"
        ERRORS=$((ERRORS + 1))
    else
        echo "OK: Removed: ${path}"
    fi
done

echo
echo "=== Project kubeconfig ==="
if [[ -f "${HOME}/.kube/config" ]]; then
    echo "ERROR: Project kubeconfig still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: Project kubeconfig removed."
fi

echo
echo "=== Project scripts ==="
if [[ -f scripts/k3s/01_install_k3s.sh ]] &&
   [[ -f scripts/k3s/08_verify_destroy.sh ]]; then
    echo "OK: Lifecycle scripts preserved."
else
    echo "ERROR: Lifecycle scripts missing."
    ERRORS=$((ERRORS + 1))
fi

echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " Phase 1 destroy verification PASSED"
    echo "========================================"
    echo "Ready for clean rebuild."
else
    echo " Phase 1 destroy verification FAILED"
    echo " Errors: ${ERRORS}"
    echo "========================================"
    exit 1
fi
