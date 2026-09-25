#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE - Prometheus"
echo "============================================================"

"${SCRIPT_DIR}/11_deploy_prometheus.sh"
"${SCRIPT_DIR}/12_verify_prometheus.sh"
"${SCRIPT_DIR}/13_test_prometheus.sh"

echo
echo "RECREATE PASSED"
