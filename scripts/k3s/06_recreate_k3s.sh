#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE K3S"
echo "============================================================"

"${SCRIPT_DIR}/01_deploy_k3s.sh"
"${SCRIPT_DIR}/02_verify_k3s.sh"
"${SCRIPT_DIR}/03_test_k3s.sh"

echo
echo "============================================================"
echo " K3S RECREATE PASSED"
echo "============================================================"
