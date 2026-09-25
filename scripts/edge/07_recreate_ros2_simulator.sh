#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo " Phase 2B.7 - Clean Recreate Simulator"
echo "========================================"

echo
echo ">>> BUILD NEW DOCKER IMAGE"
"${SCRIPT_DIR}/01_build_ros2_simulator.sh"

echo
echo ">>> CREATE NEW KUBERNETES DEPLOYMENT / POD"
"${SCRIPT_DIR}/02_deploy_ros2_simulator.sh"

echo
echo ">>> VERIFY NEW DEPLOYMENT"
"${SCRIPT_DIR}/03_verify_ros2_simulator.sh"

echo
echo ">>> ROS 2 FUNCTIONAL TEST"
"${SCRIPT_DIR}/04_test_ros2_simulator.sh"

echo
echo "========================================"
echo " Phase 2B clean recreate PASSED"
echo "========================================"
