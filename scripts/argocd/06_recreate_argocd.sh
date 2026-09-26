#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE ARGO CD"
echo "============================================================"

echo
echo "=== Deploy ==="
"${SCRIPT_DIR}/01_deploy_argocd.sh"

echo
echo "=== Verify ==="
"${SCRIPT_DIR}/02_verify_argocd.sh"

echo
echo "=== Functional test ==="
"${SCRIPT_DIR}/03_test_argocd.sh"

echo
echo "============================================================"
echo " ARGO CD RECREATE COMPLETE"
echo "============================================================"
