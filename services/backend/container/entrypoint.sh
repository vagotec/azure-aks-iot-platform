#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/jazzy/setup.bash
source /workspace/install/setup.bash

exec ros2 run \
    vagotec_backend_service \
    backend_service
