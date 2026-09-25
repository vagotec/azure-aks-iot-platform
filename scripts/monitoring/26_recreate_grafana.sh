#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE - Grafana"
echo "============================================================"

"${SCRIPT_DIR}/21_deploy_grafana.sh"
"${SCRIPT_DIR}/22_verify_grafana.sh"
"${SCRIPT_DIR}/23_test_grafana.sh"

echo
echo "RECREATE PASSED"
