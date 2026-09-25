#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo " Phase 2A.6 - Clean Recreate Mosquitto"
echo "========================================"

echo
echo ">>> Deploy"
"${SCRIPT_DIR}/01_deploy_mosquitto.sh"

echo
echo ">>> Verify"
"${SCRIPT_DIR}/02_verify_mosquitto.sh"

echo
echo ">>> MQTT 5 functional test"
"${SCRIPT_DIR}/03_test_mqtt5.sh"

echo
echo "========================================"
echo " Phase 2A clean recreate PASSED"
echo "========================================"
