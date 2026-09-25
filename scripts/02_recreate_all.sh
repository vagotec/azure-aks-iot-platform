#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "============================================================"
echo " RECREATE COMPLETE LOCAL PLATFORM"
echo "============================================================"

if command -v k3s >/dev/null 2>&1; then
    echo "ERROR: K3s already exists."
    echo "02_recreate_all.sh requires the clean destroy state."
    exit 1
fi

test -f "${PROJECT_ROOT}/config/edge.env"
test -f "${PROJECT_ROOT}/config/secrets.env"

echo
echo "=== 1/10 K3s ==="
"${PROJECT_ROOT}/scripts/k3s/01_install_k3s.sh"

echo
echo "=== 2/10 kubectl configuration ==="
"${PROJECT_ROOT}/scripts/k3s/02_configure_kubectl.sh"
"${PROJECT_ROOT}/scripts/k3s/03_verify_k3s.sh"

echo
echo "=== 3/10 Envoy Gateway + Platform Gateway ==="
"${PROJECT_ROOT}/scripts/k3s/04_install_envoy_gateway.sh"
"${PROJECT_ROOT}/scripts/k3s/05_verify_envoy_gateway.sh"

echo
echo "=== 4/10 Eclipse Mosquitto ==="
"${PROJECT_ROOT}/scripts/mqtt/01_deploy_mosquitto.sh"
"${PROJECT_ROOT}/scripts/mqtt/02_verify_mosquitto.sh"
"${PROJECT_ROOT}/scripts/mqtt/03_test_mqtt5.sh"

echo
echo "=== 5/10 ROS 2 Simulator ==="
"${PROJECT_ROOT}/scripts/edge/01_deploy_ros2_simulator.sh"
"${PROJECT_ROOT}/scripts/edge/02_verify_ros2_simulator.sh"
"${PROJECT_ROOT}/scripts/edge/03_test_ros2_simulator.sh"

echo
echo "=== 6/10 C++ Backend ==="
"${PROJECT_ROOT}/scripts/backend/01_deploy_backend.sh"
"${PROJECT_ROOT}/scripts/backend/02_verify_backend.sh"
"${PROJECT_ROOT}/scripts/backend/03_test_backend.sh"

echo
echo "=== 7/10 Mosquitto Exporter ==="
"${PROJECT_ROOT}/scripts/monitoring/01_deploy_mosquitto_exporter.sh"
"${PROJECT_ROOT}/scripts/monitoring/02_verify_mosquitto_exporter.sh"
"${PROJECT_ROOT}/scripts/monitoring/03_test_mosquitto_exporter.sh"

echo
echo "=== 8/10 Prometheus ==="
"${PROJECT_ROOT}/scripts/monitoring/11_deploy_prometheus.sh"
"${PROJECT_ROOT}/scripts/monitoring/12_verify_prometheus.sh"
"${PROJECT_ROOT}/scripts/monitoring/13_test_prometheus.sh"

echo
echo "=== 9/10 Grafana ==="
"${PROJECT_ROOT}/scripts/monitoring/21_deploy_grafana.sh"
"${PROJECT_ROOT}/scripts/monitoring/22_verify_grafana.sh"
"${PROJECT_ROOT}/scripts/monitoring/23_test_grafana.sh"

echo
echo "=== 10/10 React Frontend ==="
"${PROJECT_ROOT}/scripts/frontend/01_deploy_frontend.sh"
"${PROJECT_ROOT}/scripts/frontend/02_verify_frontend.sh"
"${PROJECT_ROOT}/scripts/frontend/03_test_frontend.sh"

echo
echo "============================================================"
echo " FINAL PLATFORM VERIFICATION"
echo "============================================================"

DEPLOYMENTS=(
    azure-aks-iot-platform-mosquitto
    azure-aks-iot-platform-ros2-simulator
    azure-aks-iot-platform-backend
    azure-aks-iot-platform-mosquitto-exporter
    azure-aks-iot-platform-prometheus
    azure-aks-iot-platform-grafana
    azure-aks-iot-platform-frontend
)

for deployment in "${DEPLOYMENTS[@]}"; do
    kubectl rollout status \
        "deployment/${deployment}" \
        -n azure-aks-iot \
        --timeout=120s
done

GATEWAY_ACCEPTED="$(
    kubectl get gateway azure-aks-iot-platform \
        -n azure-aks-iot \
        -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'
)"

GATEWAY_PROGRAMMED="$(
    kubectl get gateway azure-aks-iot-platform \
        -n azure-aks-iot \
        -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'
)"

ROUTE_ACCEPTED="$(
    kubectl get httproute azure-aks-iot-platform \
        -n azure-aks-iot \
        -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
)"

ROUTE_RESOLVED="$(
    kubectl get httproute azure-aks-iot-platform \
        -n azure-aks-iot \
        -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'
)"

echo
echo "Gateway Accepted       : ${GATEWAY_ACCEPTED}"
echo "Gateway Programmed     : ${GATEWAY_PROGRAMMED}"
echo "HTTPRoute Accepted     : ${ROUTE_ACCEPTED}"
echo "HTTPRoute ResolvedRefs : ${ROUTE_RESOLVED}"

if [[ "${GATEWAY_ACCEPTED}" != "True" ||
      "${GATEWAY_PROGRAMMED}" != "True" ||
      "${ROUTE_ACCEPTED}" != "True" ||
      "${ROUTE_RESOLVED}" != "True" ]]; then
    echo "ERROR: Gateway/HTTPRoute verification failed."
    exit 1
fi

echo
echo "=== Final Backend E2E test ==="
"${PROJECT_ROOT}/scripts/backend/03_test_backend.sh"

echo
echo "=== Final Frontend E2E test ==="
"${PROJECT_ROOT}/scripts/frontend/03_test_frontend.sh"

echo
echo "=== Final workload state ==="
kubectl get deployments,pods,services -n azure-aks-iot

echo
echo "============================================================"
echo " COMPLETE LOCAL PLATFORM RECREATE PASSED"
echo "============================================================"
