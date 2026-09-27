#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${PROJECT_ROOT}/.state/k3s"

echo "============================================================"
echo " DESTROY K3S"
echo "============================================================"

echo
echo "WARNING:"
echo "This removes the complete local K3s cluster, including"
echo "the local datastore and Local Storage Persistent Volume data."
echo

if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    sudo /usr/local/bin/k3s-uninstall.sh
else
    echo "K3s uninstall script is already absent."
fi

rm -rf "${STATE_DIR}"

echo
echo "Project-owned state removed:"
echo "  ${STATE_DIR}"
echo
echo "User kubeconfig was NOT deleted."

echo
echo "============================================================"
echo " K3S DESTROY COMPLETED"
echo "============================================================"
