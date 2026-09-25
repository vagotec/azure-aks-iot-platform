#!/usr/bin/env bash
set -eo pipefail

source /opt/ros/jazzy/setup.bash
source /workspace/install/setup.bash

exec ros2 run \
    vagotec_ros2_fake_data_generator \
    fake_data_generator
