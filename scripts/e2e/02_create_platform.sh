#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

run() {
    local name="$1"
    local script="$2"

    echo
    echo "============================================================"
    echo " ${name}"
    echo "============================================================"

    "${PROJECT_ROOT}/${script}"
}

echo "============================================================"
echo " AZURE AKS IOT PLATFORM - COMPLETE GITOPS E2E CREATE"
echo " Bootstrap: K3s -> Envoy -> Argo CD -> GitOps Platform"
echo "============================================================"

# ---------------------------------------------------------------------------
# 01 - Kubernetes bootstrap
# ---------------------------------------------------------------------------

run "01 - K3s - DEPLOY" "scripts/k3s/01_deploy_k3s.sh"
run "01 - K3s - VERIFY" "scripts/k3s/02_verify_k3s.sh"
run "01 - K3s - TEST"   "scripts/k3s/03_test_k3s.sh"

# ---------------------------------------------------------------------------
# 02 - Gateway controller bootstrap
# GatewayClass, Gateway and HTTPRoute are managed later by Argo CD.
# ---------------------------------------------------------------------------

run "02 - Envoy Gateway Controller - DEPLOY" \
    "scripts/envoy/01_deploy_envoy.sh"
run "02 - Envoy Gateway Controller - VERIFY" \
    "scripts/envoy/02_verify_envoy.sh"
run "02 - Envoy Gateway Controller - TEST" \
    "scripts/envoy/03_test_envoy.sh"

# ---------------------------------------------------------------------------
# 03 - GitOps bootstrap
# Argo CD deploys the complete platform from Git.
# 01_deploy_argocd.sh waits until the Application is Synced and Healthy.
# ---------------------------------------------------------------------------

run "03 - Argo CD / GitOps - DEPLOY PLATFORM" \
    "scripts/argocd/01_deploy_argocd.sh"
run "03 - Argo CD / GitOps - VERIFY" \
    "scripts/argocd/02_verify_argocd.sh"
run "03 - Argo CD / GitOps - TEST" \
    "scripts/argocd/03_test_argocd.sh"

# ---------------------------------------------------------------------------
# 04 - Verify and functionally test all Argo-managed platform components.
# Deployment itself is owned by Argo CD.
# ---------------------------------------------------------------------------

run "04 - Mosquitto - VERIFY" "scripts/mqtt/02_verify_mosquitto.sh"
run "04 - Mosquitto - TEST"   "scripts/mqtt/03_test_mqtt5.sh"

run "05 - ROS2 Simulator - VERIFY" "scripts/edge/02_verify_ros2_simulator.sh"
run "05 - ROS2 Simulator - TEST"   "scripts/edge/03_test_ros2_simulator.sh"

run "06 - Backend - VERIFY" "scripts/backend/02_verify_backend.sh"
run "06 - Backend - TEST"   "scripts/backend/03_test_backend.sh"

run "07 - Frontend - VERIFY" "scripts/frontend/02_verify_frontend.sh"
run "07 - Frontend - TEST"   "scripts/frontend/03_test_frontend.sh"

run "08 - Mosquitto Exporter - VERIFY" \
    "scripts/monitoring/02_verify_mosquitto_exporter.sh"
run "08 - Mosquitto Exporter - TEST" \
    "scripts/monitoring/03_test_mosquitto_exporter.sh"

run "09 - Prometheus - VERIFY" \
    "scripts/monitoring/12_verify_prometheus.sh"
run "09 - Prometheus - TEST" \
    "scripts/monitoring/13_test_prometheus.sh"

run "10 - Grafana - VERIFY" \
    "scripts/monitoring/22_verify_grafana.sh"
run "10 - Grafana - TEST" \
    "scripts/monitoring/23_test_grafana.sh"

echo
echo "============================================================"
echo " COMPLETE GITOPS E2E CREATE PASSED"
echo " Argo CD owns the platform workload deployment."
echo "============================================================"
