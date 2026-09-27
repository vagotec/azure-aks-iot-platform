# Azure AKS IoT Platform

Cloud-native IoT and robotics platform for local Kubernetes development and future deployment to Microsoft Azure Kubernetes Service (AKS).

The local Development PC environment is fully implemented and tested. It serves as the reference platform before deployment to Azure AKS.

## Architecture

    ROS 2 Simulator
          |
          v
      C++ Backend
       /       \
      v         v
   MQTT 5     REST API
      |          |
      v          v
 Mosquitto   React Frontend

Monitoring:

    Mosquitto
        |
        v
 Mosquitto Exporter
        |
        v
   Prometheus
        |
        v
     Grafana

Platform:

    K3s
     |
     +-- Envoy Gateway
     |
     +-- Argo CD
           |
           v
        GitOps

## Technology

- Ubuntu 24.04 LTS
- K3s
- Envoy Gateway
- Kubernetes Gateway API
- Argo CD
- Kustomize
- Eclipse Mosquitto MQTT 5
- ROS 2
- C++
- React
- Prometheus
- Grafana
- OpenTofu for future Azure infrastructure

## Quick Start

Create the complete local platform:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/02_create_platform.sh

Destroy the complete local platform:

    cd ~/projects/iot/azure/azure-aks-iot-platform
    ./scripts/e2e/01_destroy_platform.sh

The validated lifecycle is:

    Create
      → Verify/Test
      → Destroy
      → Verify Destroy
      → Recreate
      → Verify/Test

## Current Status

**Local Development Environment: Completed**

The complete local platform has successfully passed create, functional verification, destroy, destroy verification and recreate testing.

The next major stage is:

    Microsoft Azure
          |
          v
       OpenTofu
          |
          v
         AKS
          |
          v
    Argo CD / GitOps
          |
          v
      IoT Platform

GitHub Actions CI is intentionally deferred until later.

## Documentation

- `docs/GETTING_STARTED.md` — complete usage and component lifecycle commands
- `docs/REQUIREMENTS.md` — local Development PC requirements
- `docs/STATUS.md` — detailed implementation and test status

## Repository

    https://github.com/vagotec/azure-aks-iot-platform
