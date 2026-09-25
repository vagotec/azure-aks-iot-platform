#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "============================================================"
echo " RECREATE C++ BACKEND SERVICE"
echo "============================================================"

echo
echo ">>> DEPLOY"
"${PROJECT_ROOT}/scripts/backend/01_deploy_backend.sh"

echo
echo ">>> VERIFY"
"${PROJECT_ROOT}/scripts/backend/02_verify_backend.sh"

echo
echo ">>> FUNCTIONAL TEST"
"${PROJECT_ROOT}/scripts/backend/03_test_backend.sh"

echo
echo "============================================================"
echo " BACKEND RECREATE LIFECYCLE PASSED"
echo "============================================================"
