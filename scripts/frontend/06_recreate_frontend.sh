#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE - React Frontend"
echo "============================================================"

echo
echo ">>> DEPLOY"
"${SCRIPT_DIR}/01_deploy_frontend.sh"

echo
echo ">>> VERIFY"
"${SCRIPT_DIR}/02_verify_frontend.sh"

echo
echo ">>> FUNCTIONAL TEST"
"${SCRIPT_DIR}/03_test_frontend.sh"

echo
echo "============================================================"
echo " FRONTEND RECREATE LIFECYCLE PASSED"
echo "============================================================"
