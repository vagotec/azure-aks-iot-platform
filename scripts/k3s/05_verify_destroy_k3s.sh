#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${PROJECT_ROOT}/.state/k3s"

echo "============================================================"
echo " VERIFY K3S DESTROY"
echo "============================================================"

ERRORS=0

if command -v k3s >/dev/null 2>&1; then
    echo "ERROR: K3s binary still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: K3s binary absent."
fi

if systemctl list-unit-files --no-legend 2>/dev/null |
   awk '{print $1}' |
   grep -qx 'k3s.service'; then
    echo "ERROR: k3s.service still exists."
    ERRORS=$((ERRORS + 1))
else
    echo "OK: k3s.service absent."
fi

for path in \
    /etc/rancher/k3s \
    /var/lib/rancher/k3s \
    "${STATE_DIR}"
do
    if sudo test -e "${path}"; then
        echo "ERROR: Still exists: ${path}"
        ERRORS=$((ERRORS + 1))
    else
        echo "OK: Removed: ${path}"
    fi
done

echo
echo "============================================================"

if [[ "${ERRORS}" -eq 0 ]]; then
    echo " K3S DESTROY VERIFICATION PASSED"
    echo "============================================================"
    exit 0
fi

echo " K3S DESTROY VERIFICATION FAILED"
echo " Errors: ${ERRORS}"
echo "============================================================"
exit 1
