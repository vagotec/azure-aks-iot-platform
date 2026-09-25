cmake_minimum_required(VERSION 3.8)
project(vagotec_ros2_fake_data_generator)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)

add_executable(fake_data_generator
  fake_data_generator.cpp
)

ament_target_dependencies(fake_data_generator
  rclcpp
  std_msgs
)

install(TARGETS
  fake_data_generator
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
