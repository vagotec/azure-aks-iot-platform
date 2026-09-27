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
echo " AZURE AKS IOT PLATFORM - COMPLETE GITOPS E2E DESTROY"
echo "============================================================"

# ---------------------------------------------------------------------------
# Stop GitOps reconciliation first.
#
# Argo CD self-healing must no longer be active before managed workload
# resources are removed.
# ---------------------------------------------------------------------------

run "01 - Argo CD / GitOps - DESTROY" \
    "scripts/argocd/04_destroy_argocd.sh"

run "01 - Argo CD / GitOps - VERIFY DESTROY" \
    "scripts/argocd/05_verify_destroy_argocd.sh"

# ---------------------------------------------------------------------------
# Remove platform workloads in reverse dependency order.
# ---------------------------------------------------------------------------

run "02 - Grafana - DESTROY" \
    "scripts/monitoring/24_destroy_grafana.sh"

run "03 - Prometheus - DESTROY" \
    "scripts/monitoring/14_destroy_prometheus.sh"

run "04 - Mosquitto Exporter - DESTROY" \
    "scripts/monitoring/04_destroy_mosquitto_exporter.sh"

run "05 - Frontend - DESTROY" \
    "scripts/frontend/04_destroy_frontend.sh"

run "06 - Backend - DESTROY" \
    "scripts/backend/04_destroy_backend.sh"

run "07 - ROS2 Simulator - DESTROY" \
    "scripts/edge/04_destroy_ros2_simulator.sh"

run "08 - Mosquitto - DESTROY" \
    "scripts/mqtt/04_destroy_mosquitto.sh"

# ---------------------------------------------------------------------------
# Remove bootstrap infrastructure.
# ---------------------------------------------------------------------------

run "09 - Envoy Gateway Controller - DESTROY" \
    "scripts/envoy/04_destroy_envoy.sh"

run "09 - Envoy Gateway Controller - VERIFY DESTROY" \
    "scripts/envoy/05_verify_destroy_envoy.sh"

run "10 - K3s - DESTROY" \
    "scripts/k3s/04_destroy_k3s.sh"

run "10 - K3s - VERIFY DESTROY" \
    "scripts/k3s/05_verify_destroy_k3s.sh"

echo
echo "============================================================"
echo " COMPLETE GITOPS E2E DESTROY PASSED"
echo "============================================================"
