cmake_minimum_required(VERSION 3.8)
project(vagotec_backend_service)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(PahoMqttCpp REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(CPPHTTPLIB REQUIRED IMPORTED_TARGET cpp-httplib)

add_executable(backend_service
  backend_service.cpp
  rest_server.cpp
)

ament_target_dependencies(backend_service
  rclcpp
  std_msgs
)

target_link_libraries(backend_service
  PahoMqttCpp::paho-mqttpp3
  PkgConfig::CPPHTTPLIB
)

install(TARGETS
  backend_service
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
