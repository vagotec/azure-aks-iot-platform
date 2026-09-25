#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE - Mosquitto Exporter"
echo "============================================================"

"${SCRIPT_DIR}/01_deploy_mosquitto_exporter.sh"
"${SCRIPT_DIR}/02_verify_mosquitto_exporter.sh"
"${SCRIPT_DIR}/03_test_mosquitto_exporter.sh"

echo
echo "RECREATE PASSED"
