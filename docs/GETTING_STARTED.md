# Getting Started

This guide describes how to set up, deploy, verify, destroy and recreate the complete local Development PC environment of the Azure AKS IoT Platform.

For a list of general host requirements, see:

    docs/REQUIREMENTS.md

---

## 1. Prepare the Development PC

The tested development environment is Ubuntu 24.04 LTS.

The following host tools must be available before starting the project:

- Git
- Docker
- kubectl
- Helm
- curl
- jq
- OpenSSL
- Python 3
- Bash
- sudo
- ip
- awk
- grep

Verify the important tools:

    git --version
    docker --version
    kubectl version --client
    helm version
    curl --version
    jq --version
    openssl version
    python3 --version

Docker must be running because local application images are built during the project lifecycle.

Verify Docker:

    sudo systemctl is-active docker
    docker info

If Docker is installed but not running:

    sudo systemctl enable --now docker

K3s does NOT need to be installed manually.

The project installs the configured K3s version automatically.

---

## 2. Clone the Repository

For a new installation:

    cd ~/projects/iot/azure
    git clone https://github.com/vagotec/azure-aks-iot-platform.git
    cd azure-aks-iot-platform

For an existing installation:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    git status

---

## 3. Create the Local Configuration

The project requires three local configuration files:

    config/k3s.env
    config/edge.env
    config/secrets.env

Create them from the tracked examples:

    cd ~/projects/iot/azure/azure-aks-iot-platform

    cp config/k3s.env.example config/k3s.env
    cp config/edge.env.example config/edge.env
    cp config/secrets.env.example config/secrets.env

These files are machine-specific or contain local secrets and are excluded from Git.

Do not commit them.

---

## 4. Configure K3s

Edit:

    config/k3s.env

The example configuration contains:

    K3S_VERSION=v1.36.4+k3s1
    K3S_NODE_NAME=development-pc
    K3S_NETWORK_INTERFACE=wlp129s0f0
    K3S_NODE_IP=auto
    K3S_CLUSTER_CIDR=10.42.0.0/16
    K3S_SERVICE_CIDR=10.43.0.0/16
    K3S_DISABLE_TRAEFIK=true

The most important machine-specific value is:

    K3S_NETWORK_INTERFACE

Find the available interfaces with:

    ip -br link
    ip -4 addr

Set `K3S_NETWORK_INTERFACE` to the interface used by the Development PC.

With:

    K3S_NODE_IP=auto

the deployment script automatically resolves the IPv4 address assigned to that interface.

The project disables the K3s packaged Traefik installation because Envoy Gateway is used instead.

---

## 5. Configure the Platform

Edit:

    config/edge.env

The example already contains the tested local configuration for:

- Kubernetes namespace
- Mosquitto
- MQTT 5
- ROS 2 Simulator
- C++ Backend
- REST API
- React Frontend
- Envoy Gateway
- Mosquitto Exporter
- Prometheus
- Grafana

For the tested local reference environment, start with the provided example values.

Only change values when required for the local Development PC or a deliberate project configuration change.

---

## 6. Configure Local Secrets

Edit:

    config/secrets.env

The example contains:

    GRAFANA_ADMIN_PASSWORD=CHANGE_ME

Replace `CHANGE_ME` with a local Grafana administrator password.

For example, generate a password with:

    openssl rand -base64 24

Then store the generated value in:

    config/secrets.env

Example:

    GRAFANA_ADMIN_PASSWORD=<your-local-password>

Do not commit this file.

Verify that Git ignores the local configuration:

    git check-ignore -v \
      config/k3s.env \
      config/edge.env \
      config/secrets.env

All three files should be reported as ignored.

---

## 7. Pre-Deployment Check

Before starting the complete platform:

    cd ~/projects/iot/azure/azure-aks-iot-platform

    test -f config/k3s.env && echo "OK: config/k3s.env"
    test -f config/edge.env && echo "OK: config/edge.env"
    test -f config/secrets.env && echo "OK: config/secrets.env"

    docker info >/dev/null && echo "OK: Docker"

    command -v git
    command -v docker
    command -v kubectl
    command -v helm
    command -v curl
    command -v jq
    command -v openssl
    command -v python3
    command -v ip
    command -v awk
    command -v grep

K3s should not already be installed when performing a clean zero-state deployment:

    if command -v k3s >/dev/null 2>&1; then
        echo "K3s is already installed."
    else
        echo "OK: Clean K3s zero-state."
    fi

If K3s belongs to this project and is already installed, use the project lifecycle scripts instead of manually modifying the installation.

---

# Complete Platform Installation

## 8. Create the Complete Platform

The normal installation path is the complete E2E create script:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/02_create_platform.sh

This is the recommended way to create the complete local platform.

The script performs the bootstrap in dependency order:

    K3s
      |
      v
    Envoy Gateway
      |
      v
    Argo CD
      |
      v
    GitOps Platform
      |
      +-- Mosquitto MQTT 5
      +-- ROS 2 Simulator
      +-- C++ Backend
      +-- React Frontend
      +-- Mosquitto Exporter
      +-- Prometheus
      +-- Grafana

It also executes verification and functional tests.

---

## 9. What the Complete Create Does

### Step 1 - K3s

The project installs the configured K3s version.

The deployment script:

- validates `config/k3s.env`
- resolves the configured network interface and node IP
- creates the K3s configuration
- installs K3s
- starts the K3s systemd service
- waits for the Kubernetes API
- waits for the node to become Ready
- waits for K3s system deployments
- creates the project-owned kubeconfig

The project kubeconfig is:

    .state/k3s/kubeconfig

The user Kubernetes configuration is not replaced.

### Step 2 - Envoy Gateway

The project installs the Envoy Gateway controller using Helm.

The K3s packaged Traefik controller remains disabled.

### Step 3 - Argo CD

The project installs the pinned Argo CD version.

Argo CD then applies the declarative GitOps configuration.

The GitOps application creates the platform namespace:

    azure-aks-iot

The local Grafana Kubernetes Secret is created from:

    config/secrets.env

The secret itself is not stored in Git.

### Step 4 - GitOps Platform

Argo CD deploys the application workloads from Git.

The deployment waits until the Argo CD Application reaches:

    Synced
    Healthy

### Step 5 - Functional Tests

The E2E create then verifies and tests:

- Mosquitto MQTT 5
- ROS 2 Simulator
- C++ Backend
- React Frontend
- Mosquitto Exporter
- Prometheus
- Grafana

A successful complete installation ends with:

    COMPLETE GITOPS E2E CREATE PASSED
    Argo CD owns the platform workload deployment.

---

## 10. Verify the Running System

After successful creation:

    cd ~/projects/iot/azure/azure-aks-iot-platform

    export KUBECONFIG="$PWD/.state/k3s/kubeconfig"

    kubectl get nodes -o wide
    kubectl get pods -A
    kubectl get application azure-aks-iot-platform -n argocd
    kubectl get pods -n azure-aks-iot

    unset KUBECONFIG

The K3s node should be:

    Ready

The Argo CD Application should be:

    Synced
    Healthy

The application workloads should be running in:

    azure-aks-iot

---

# Complete Platform Lifecycle

## 11. Destroy the Complete Platform

To completely remove the local project environment:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/01_destroy_platform.sh

The script removes the project environment in dependency order and verifies the teardown.

A successful run ends with:

    COMPLETE GITOPS E2E DESTROY PASSED

The K3s installation created by the project is removed.

Project-owned K3s runtime state is removed.

Unrelated user Kubernetes configuration is not deleted.

---

## 12. Recreate the Complete Platform

After a successful destroy:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/02_create_platform.sh

The complete validated lifecycle is:

    Zero State
        |
        v
      Create
        |
        v
    Verify/Test
        |
        v
      Destroy
        |
        v
    Verify Destroy
        |
        v
     Recreate
        |
        v
    Verify/Test

---

# Individual Component Lifecycle

The complete E2E lifecycle is the normal way to operate the full platform.

The following scripts are available when developing or testing individual components.

Dependencies must already be running when a component is operated independently.

---

## 13. K3s

Deploy:

    ./scripts/k3s/01_deploy_k3s.sh

Verify:

    ./scripts/k3s/02_verify_k3s.sh

Test:

    ./scripts/k3s/03_test_k3s.sh

Destroy:

    ./scripts/k3s/04_destroy_k3s.sh

Verify Destroy:

    ./scripts/k3s/05_verify_destroy_k3s.sh

Recreate:

    ./scripts/k3s/06_recreate_k3s.sh

---

## 14. Envoy Gateway

Deploy:

    ./scripts/envoy/01_deploy_envoy.sh

Verify:

    ./scripts/envoy/02_verify_envoy.sh

Test:

    ./scripts/envoy/03_test_envoy.sh

Destroy:

    ./scripts/envoy/04_destroy_envoy.sh

Verify Destroy:

    ./scripts/envoy/05_verify_destroy_envoy.sh

Recreate:

    ./scripts/envoy/06_recreate_envoy.sh

---

## 15. Argo CD

Deploy:

    ./scripts/argocd/01_deploy_argocd.sh

Verify:

    ./scripts/argocd/02_verify_argocd.sh

Test:

    ./scripts/argocd/03_test_argocd.sh

Destroy:

    ./scripts/argocd/04_destroy_argocd.sh

Verify Destroy:

    ./scripts/argocd/05_verify_destroy_argocd.sh

Recreate:

    ./scripts/argocd/06_recreate_argocd.sh

Local secret bootstrap:

    ./scripts/argocd/00_bootstrap_local_secrets.sh

---

## 16. Mosquitto MQTT 5

Deploy:

    ./scripts/mqtt/01_deploy_mosquitto.sh

Verify:

    ./scripts/mqtt/02_verify_mosquitto.sh

Test:

    ./scripts/mqtt/03_test_mqtt5.sh

Destroy:

    ./scripts/mqtt/04_destroy_mosquitto.sh

Verify Destroy:

    ./scripts/mqtt/05_verify_destroy.sh

Recreate:

    ./scripts/mqtt/06_recreate_mosquitto.sh

---

## 17. ROS 2 Simulator

Deploy:

    ./scripts/edge/01_deploy_ros2_simulator.sh

Verify:

    ./scripts/edge/02_verify_ros2_simulator.sh

Test:

    ./scripts/edge/03_test_ros2_simulator.sh

Destroy:

    ./scripts/edge/04_destroy_ros2_simulator.sh

Verify Destroy:

    ./scripts/edge/05_verify_ros2_simulator_destroy.sh

Recreate:

    ./scripts/edge/06_recreate_ros2_simulator.sh

---

## 18. C++ Backend

Deploy:

    ./scripts/backend/01_deploy_backend.sh

Verify:

    ./scripts/backend/02_verify_backend.sh

Test:

    ./scripts/backend/03_test_backend.sh

Destroy:

    ./scripts/backend/04_destroy_backend.sh

Verify Destroy:

    ./scripts/backend/05_verify_backend_destroy.sh

Recreate:

    ./scripts/backend/06_recreate_backend.sh

---

## 19. React Frontend

Deploy:

    ./scripts/frontend/01_deploy_frontend.sh

Verify:

    ./scripts/frontend/02_verify_frontend.sh

Test:

    ./scripts/frontend/03_test_frontend.sh

Standalone Destroy:

    ./scripts/frontend/04_destroy_frontend.sh

Verify Destroy:

    ./scripts/frontend/05_verify_frontend_destroy.sh

Recreate:

    ./scripts/frontend/06_recreate_frontend.sh

The complete GitOps E2E destroy uses:

    ./scripts/frontend/06_destroy_frontend_gitops.sh

The GitOps-specific destroy preserves the GitOps-owned HTTPRoute.

---

## 20. Mosquitto Exporter

Deploy:

    ./scripts/monitoring/01_deploy_mosquitto_exporter.sh

Verify:

    ./scripts/monitoring/02_verify_mosquitto_exporter.sh

Test:

    ./scripts/monitoring/03_test_mosquitto_exporter.sh

Destroy:

    ./scripts/monitoring/04_destroy_mosquitto_exporter.sh

Verify Destroy:

    ./scripts/monitoring/05_verify_mosquitto_exporter_destroy.sh

Recreate:

    ./scripts/monitoring/06_recreate_mosquitto_exporter.sh

---

## 21. Prometheus

Deploy:

    ./scripts/monitoring/11_deploy_prometheus.sh

Verify:

    ./scripts/monitoring/12_verify_prometheus.sh

Test:

    ./scripts/monitoring/13_test_prometheus.sh

Destroy:

    ./scripts/monitoring/14_destroy_prometheus.sh

Verify Destroy:

    ./scripts/monitoring/15_verify_prometheus_destroy.sh

Recreate:

    ./scripts/monitoring/16_recreate_prometheus.sh

---

## 22. Grafana

Deploy:

    ./scripts/monitoring/21_deploy_grafana.sh

Verify:

    ./scripts/monitoring/22_verify_grafana.sh

Test:

    ./scripts/monitoring/23_test_grafana.sh

Destroy:

    ./scripts/monitoring/24_destroy_grafana.sh

Verify Destroy:

    ./scripts/monitoring/25_verify_grafana_destroy.sh

Recreate:

    ./scripts/monitoring/26_recreate_grafana.sh

---

# Basic Diagnostics

## 23. Kubernetes

Use the project kubeconfig:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    export KUBECONFIG="$PWD/.state/k3s/kubeconfig"

Check the cluster:

    kubectl get nodes -o wide
    kubectl get pods -A

Check the platform:

    kubectl get pods -n azure-aks-iot
    kubectl get services -n azure-aks-iot

Check Argo CD:

    kubectl get application azure-aks-iot-platform -n argocd

Check recent platform events:

    kubectl get events \
      -n azure-aks-iot \
      --sort-by='.lastTimestamp' |
      tail -50

When finished:

    unset KUBECONFIG

Detailed troubleshooting belongs in:

    docs/TROUBLESHOOTING.md

---

# Normal Development Workflow

## 24. Full Platform

For a clean complete environment:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/01_destroy_platform.sh
    ./scripts/e2e/02_create_platform.sh

For an initial zero-state installation where the project K3s environment does not yet exist:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/02_create_platform.sh

For component development, use the individual lifecycle scripts documented above.

For GitOps-managed resources, Git remains the source of truth.

---

# Next Stage

The local Development PC environment is complete.

The next major project stage is deployment to Microsoft Azure:

    OpenTofu
       |
       v
    Azure Infrastructure
       |
       v
      AKS
       |
       v
    Argo CD
       |
       v
    GitOps Platform

The local K3s environment remains the reference implementation for the AKS deployment.
