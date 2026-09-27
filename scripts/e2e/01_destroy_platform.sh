#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_KUBECONFIG="${PROJECT_ROOT}/.state/k3s/kubeconfig"

cd "${PROJECT_ROOT}"

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
# Use the project-owned K3s kubeconfig for all Kubernetes operations.
# ---------------------------------------------------------------------------

if [[ ! -f "${PROJECT_KUBECONFIG}" ]]; then
    echo "ERROR: Project kubeconfig does not exist:"
    echo "  ${PROJECT_KUBECONFIG}"
    echo
    echo "The E2E destroy requires the project-owned kubeconfig while K3s exists."
    exit 1
fi

export KUBECONFIG="${PROJECT_KUBECONFIG}"

echo
echo "=== Project Kubernetes context ==="
echo "KUBECONFIG=${KUBECONFIG}"

kubectl get nodes >/dev/null

echo "OK: Kubernetes API reachable through project kubeconfig."

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
    "scripts/frontend/06_destroy_frontend_gitops.sh"

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

# K3s destroy may remove the project-owned kubeconfig.
# Verification must therefore not depend on kubectl afterwards.

unset KUBECONFIG

run "10 - K3s - VERIFY DESTROY" \
    "scripts/k3s/05_verify_destroy_k3s.sh"

echo
echo "============================================================"
echo " COMPLETE GITOPS E2E DESTROY PASSED"
echo "============================================================"
