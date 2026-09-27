# Project Status

Current implementation and validation status of the Azure AKS IoT Platform.

This document records what has been implemented, tested and deferred.

Installation and operating instructions are documented in:

    docs/GETTING_STARTED.md

---

## 1. Current Milestone

**Local Development Environment: COMPLETED**

The complete local K3s-based platform has been implemented and validated on the Development PC.

The validated lifecycle is:

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

The local environment is now the reference implementation for the future Azure AKS deployment.

---

## 2. Platform Status

| Component | Status |
|---|---|
| Local K3s Cluster | Completed |
| Project-owned Kubeconfig | Completed |
| Envoy Gateway | Completed |
| Kubernetes Gateway API | Completed |
| Argo CD | Completed |
| GitOps / Kustomize | Completed |
| Application Namespace | Completed |
| Local Secret Bootstrap | Completed |
| Mosquitto MQTT 5 | Completed |
| ROS 2 Simulator | Completed |
| C++ Backend | Completed |
| REST API | Completed |
| React Frontend | Completed |
| Mosquitto Exporter | Completed |
| Prometheus | Completed |
| Grafana | Completed |

---

## 3. Tested Versions

The completed local reference environment was validated with:

| Component | Version |
|---|---|
| Operating System | Ubuntu 24.04 LTS |
| K3s | v1.36.4+k3s1 |
| Envoy Gateway | v1.9.1 |
| Argo CD | v3.5.3 |
| Eclipse Mosquitto | 2.1.2-alpine |
| Mosquitto Exporter | v0.2.51 |
| Prometheus | v3.14.0 |
| Grafana | 13.0.2 |

Other development tools and their host requirements are documented in:

    docs/REQUIREMENTS.md

---

## 4. Complete Lifecycle Validation

| Lifecycle Step | Result |
|---|---|
| Zero-state bootstrap | Passed |
| Complete Create | Passed |
| Component Verification | Passed |
| Functional Tests | Passed |
| Complete Destroy | Passed |
| Verify Destroy | Passed |
| Complete Recreate | Passed |
| Final Verification | Passed |
| Final Functional Tests | Passed |

The complete lifecycle has therefore been validated as:

    Create
      → Verify/Test
      → Destroy
      → Verify Destroy
      → Recreate
      → Verify/Test

---

## 5. K3s

Status:

    COMPLETED

Validated:

- clean K3s installation
- configured node identity
- configured network interface
- configured cluster CIDR
- configured service CIDR
- Traefik disabled
- Kubernetes API reachable
- node registration
- node Ready
- K3s system deployments
- project-owned kubeconfig
- complete uninstall
- destroy verification
- recreate

The project-owned kubeconfig is stored under:

    .state/k3s/kubeconfig

The lifecycle does not delete unrelated user Kubernetes configuration.

---

## 6. Envoy Gateway

Status:

    COMPLETED

Validated:

- Envoy Gateway controller installation
- controller availability
- Gateway API integration
- destroy
- destroy verification
- recreate

The K3s packaged Traefik controller is disabled.

Envoy Gateway is the ingress and Gateway API implementation for the project.

---

## 7. Argo CD / GitOps

Status:

    COMPLETED

Validated:

- Argo CD installation
- declarative AppProject
- declarative Application
- Kustomize integration
- declarative application namespace
- local secret bootstrap
- synchronization
- health verification
- destroy
- destroy verification
- recreate

Expected final Application state:

    Synced
    Healthy

Argo CD owns deployment of the GitOps-managed platform workloads.

---

## 8. Application Namespace

Status:

    COMPLETED

Namespace:

    azure-aks-iot

The namespace is managed declaratively through GitOps.

It is not implicitly created through the Argo CD `CreateNamespace` sync option.

This keeps namespace ownership explicit.

---

## 9. Local Secret Bootstrap

Status:

    COMPLETED

Local secrets are stored outside Git in:

    config/secrets.env

The Argo CD bootstrap process creates the required Kubernetes Secret after the GitOps namespace exists.

Validated:

- local secret file
- placeholder rejection
- namespace readiness
- Kubernetes Secret creation
- Secret verification
- no real secret stored in Git

---

## 10. Mosquitto MQTT 5

Status:

    COMPLETED

Validated:

- deployment
- service
- MQTT 5 connectivity
- QoS 1 publish/subscribe
- functional test
- destroy
- destroy verification
- recreate

---

## 11. ROS 2 Simulator

Status:

    COMPLETED

Validated:

- container image build
- Kubernetes deployment
- ROS 2 telemetry
- command service
- command round-trip
- destroy
- destroy verification
- recreate

---

## 12. C++ Backend

Status:

    COMPLETED

Validated data flows include:

    ROS 2
      |
      v
    C++ Backend
      |
      v
    MQTT 5

and:

    MQTT 5
      |
      v
    C++ Backend
      |
      v
    ROS 2 Service
      |
      v
    Simulator

REST functionality was also validated.

Validated:

- local container build
- Kubernetes deployment
- ROS 2 integration
- MQTT 5 integration
- REST health
- telemetry flow
- command round-trip
- destroy
- destroy verification
- recreate

---

## 13. React Frontend

Status:

    COMPLETED

Validated:

- local container build
- Kubernetes deployment
- Kubernetes service
- Envoy routing
- frontend availability
- backend API access
- destroy
- destroy verification
- recreate

A dedicated GitOps-aware destroy path preserves the GitOps-owned HTTPRoute during the complete E2E teardown.

---

## 14. Mosquitto Exporter

Status:

    COMPLETED

Validated:

- deployment
- connection to Mosquitto
- metrics endpoint
- broker metrics
- destroy
- destroy verification
- recreate

---

## 15. Prometheus

Status:

    COMPLETED

Validated:

- deployment
- configuration
- Mosquitto Exporter target
- target UP
- broker metrics
- destroy
- destroy verification
- recreate

---

## 16. Grafana

Status:

    COMPLETED

Validated:

- deployment
- local administrator Secret
- service
- persistent storage
- provisioning
- Prometheus connectivity
- dashboard provisioning
- application health
- destroy
- destroy verification
- recreate

Transient startup messages observed during testing did not prevent Grafana from becoming healthy or passing the functional checks.

---

## 17. End-to-End Application Validation

The following functional chain has been validated:

    ROS 2
      |
      v
    C++ Backend
      |
      v
    MQTT 5

The reverse command path has also been validated:

    MQTT 5
      |
      v
    C++ Backend
      |
      v
    ROS 2 Service
      |
      v
    Simulator

The HTTP path has been validated through Envoy Gateway:

    Client
      |
      v
    Envoy Gateway
      |
      +----> React Frontend
      |
      +----> Backend REST API

The monitoring path has been validated:

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

---

## 18. Resource Ownership

Resource ownership has been validated during the complete destroy lifecycle.

Important ownership rules:

- K3s lifecycle owns the project local Kubernetes installation.
- Envoy lifecycle owns the Envoy Gateway controller.
- Argo CD lifecycle owns the GitOps controller.
- GitOps owns declarative application resources.
- Component scripts own their corresponding runtime resources.
- Individual component destroy operations must not remove unrelated resources.

The frontend has a dedicated GitOps-aware destroy path so that the HTTPRoute remains owned by GitOps during E2E teardown.

Detailed lifecycle documentation belongs in:

    docs/LIFECYCLE.md

---

## 19. Local Development Milestone

The local Development PC milestone is complete.

The following acceptance criteria have been met:

- complete platform can be created from zero-state
- infrastructure and workloads become healthy
- functional communication paths pass
- monitoring path passes
- GitOps Application becomes Synced and Healthy
- platform can be completely destroyed
- destroy state can be verified
- platform can be recreated
- final functional tests pass

No additional local platform phase is required before beginning the Azure infrastructure work.

---

## 20. Deferred Work

The following work is intentionally deferred:

### GitHub Actions CI

GitHub Actions CI is not required for the current milestone.

It can be added after the Azure/AKS environment is stable.

### Production Hardening

Production hardening can include areas such as:

- immutable container image references
- production secret management
- additional security controls
- high availability
- scaling
- backup and recovery
- production observability policies

These are not blockers for beginning the AKS implementation.

---

## 21. Azure / AKS Status

Status:

    NOT YET IMPLEMENTED

The local platform is complete.

The next major stage is:

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
       |
       v
    Azure E2E Validation

Azure infrastructure will be managed as Infrastructure as Code with OpenTofu.

The local K3s environment remains the reference implementation while the AKS deployment is developed.

---

## 22. Documentation Status

| Document | Status |
|---|---|
| README.md | Completed |
| docs/REQUIREMENTS.md | Completed |
| docs/GETTING_STARTED.md | Completed |
| docs/STATUS.md | Completed |
| docs/ARCHITECTURE.md | Planned |
| docs/LIFECYCLE.md | Planned |
| docs/TROUBLESHOOTING.md | Planned |

The planned documents will contain detailed architecture, lifecycle ownership and troubleshooting information without duplicating the existing Getting Started guide.

---

## 23. Current Project State

Current milestone:

    Local Development Environment
    COMPLETED

Next milestone:

    Azure Infrastructure / AKS

Deferred:

    GitHub Actions CI
    Production Hardening

The project is ready to proceed from the validated local K3s reference environment to the Azure/AKS implementation.
