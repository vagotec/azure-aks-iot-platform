#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo " Recreate Envoy Gateway Controller"
echo "========================================"

"${SCRIPT_DIR}/01_deploy_envoy.sh"
"${SCRIPT_DIR}/02_verify_envoy.sh"
"${SCRIPT_DIR}/03_test_envoy.sh"

echo "========================================"
echo " Envoy Gateway recreate PASSED"
echo "========================================"
