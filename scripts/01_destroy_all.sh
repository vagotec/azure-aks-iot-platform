#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "============================================================"
echo " DESTROY COMPLETE LOCAL PLATFORM"
echo "============================================================"
echo
echo "WARNING:"
echo "  This removes the complete local K3s platform."
echo "  Local K3s persistent-volume data will be deleted."
echo

if ! command -v k3s >/dev/null 2>&1; then
    echo "ERROR: K3s is not installed."
    echo "The local platform is already absent or incomplete."
    exit 1
fi

echo "=== 1/9 React Frontend ==="
"${PROJECT_ROOT}/scripts/frontend/04_destroy_frontend.sh"
"${PROJECT_ROOT}/scripts/frontend/05_verify_frontend_destroy.sh"

echo
echo "=== 2/9 Grafana ==="
"${PROJECT_ROOT}/scripts/monitoring/24_destroy_grafana.sh"
"${PROJECT_ROOT}/scripts/monitoring/25_verify_grafana_destroy.sh"

echo
echo "=== 3/9 Prometheus ==="
"${PROJECT_ROOT}/scripts/monitoring/14_destroy_prometheus.sh"
"${PROJECT_ROOT}/scripts/monitoring/15_verify_prometheus_destroy.sh"

echo
echo "=== 4/9 Mosquitto Exporter ==="
"${PROJECT_ROOT}/scripts/monitoring/04_destroy_mosquitto_exporter.sh"
"${PROJECT_ROOT}/scripts/monitoring/05_verify_mosquitto_exporter_destroy.sh"

echo
echo "=== 5/9 C++ Backend ==="
"${PROJECT_ROOT}/scripts/backend/04_destroy_backend.sh"
"${PROJECT_ROOT}/scripts/backend/05_verify_backend_destroy.sh"

echo
echo "=== 6/9 ROS 2 Simulator ==="
"${PROJECT_ROOT}/scripts/edge/04_destroy_ros2_simulator.sh"
"${PROJECT_ROOT}/scripts/edge/05_verify_ros2_simulator_destroy.sh"

echo
echo "=== 7/9 Eclipse Mosquitto ==="
"${PROJECT_ROOT}/scripts/mqtt/04_destroy_mosquitto.sh"
"${PROJECT_ROOT}/scripts/mqtt/05_verify_destroy.sh"

echo
echo "=== 8/9 Envoy Gateway + Platform Gateway ==="
"${PROJECT_ROOT}/scripts/k3s/06_destroy_envoy_gateway.sh"

echo
echo "=== 9/9 K3s ==="
"${PROJECT_ROOT}/scripts/k3s/07_destroy_k3s.sh"
"${PROJECT_ROOT}/scripts/k3s/08_verify_destroy.sh"

echo
echo "=== Final independent verification ==="

if command -v k3s >/dev/null 2>&1; then
    echo "ERROR: k3s command still exists."
    exit 1
fi

if [[ -e /usr/local/bin/k3s-uninstall.sh ]]; then
    echo "ERROR: K3s uninstall script still exists."
    exit 1
fi

if sudo test -e /var/lib/rancher/k3s; then
    echo "ERROR: K3s data directory still exists."
    exit 1
fi

if [[ -e "${HOME}/.kube/config" ]]; then
    echo "ERROR: Project kubeconfig still exists."
    exit 1
fi

test -f "${PROJECT_ROOT}/config/edge.env"
test -f "${PROJECT_ROOT}/config/secrets.env"

echo
echo "============================================================"
echo " COMPLETE LOCAL PLATFORM DESTROY PASSED"
echo "============================================================"
