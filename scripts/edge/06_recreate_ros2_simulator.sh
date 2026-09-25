#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo " RECREATE - ROS 2 Simulator"
echo "============================================================"

echo
echo ">>> DEPLOY"
"${SCRIPT_DIR}/01_deploy_ros2_simulator.sh"

echo
echo ">>> VERIFY"
"${SCRIPT_DIR}/02_verify_ros2_simulator.sh"

echo
echo ">>> FUNCTIONAL TEST"
"${SCRIPT_DIR}/03_test_ros2_simulator.sh"

echo
echo "============================================================"
echo " ROS 2 SIMULATOR RECREATE LIFECYCLE PASSED"
echo "============================================================"
