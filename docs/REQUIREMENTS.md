# Requirements

Requirements for running the Azure AKS IoT Platform on the local Development PC.

This document only describes prerequisites. Installation, deployment and lifecycle instructions are documented in `GETTING_STARTED.md`.

## Operating System

Tested development environment:

    Ubuntu 24.04 LTS
    x86_64
    systemd

The user requires `sudo` access.

## Required Software

The following tools must be available:

- Git
- Docker
- kubectl
- Helm
- curl
- jq
- OpenSSL
- Bash

Verify:

    git --version
    docker --version
    kubectl version --client
    helm version
    curl --version
    jq --version
    openssl version
    bash --version

Docker must be running:

    docker info

## K3s

K3s does not need to be installed manually before the complete project create process.

The project lifecycle scripts install and configure the local K3s environment.

Tested version:

    v1.36.4+k3s1

## Network

The Development PC requires:

- IPv4 networking
- Internet access
- access to GitHub
- access to required container registries
- access to Helm repositories

The local Kubernetes network ranges are:

    Pod CIDR:      10.42.0.0/16
    Service CIDR:  10.43.0.0/16

These ranges must not conflict with the local network.

## Local Configuration

Local environment configuration is stored in:

    config/edge.env
    config/k3s.env
    config/secrets.env

These files are local and must not be committed to Git.

Example configuration files are provided in the repository.

## Secrets

Real passwords, tokens, credentials, certificates and private keys must never be committed.

Local secrets are stored in:

    config/secrets.env

The file is excluded through `.gitignore`.

## Disk and Resources

The Development PC must provide sufficient CPU, memory and disk space for:

- K3s
- application containers
- Docker image builds
- Prometheus
- Grafana
- local persistent volumes

The exact resource requirement depends on the workloads running on the Development PC.

## Next

For installation and operation:

    docs/GETTING_STARTED.md
