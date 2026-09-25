#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <iomanip>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include "vagotec_iot_interfaces/srv/device_command.hpp"

namespace
{

std::string require_env(const char *name)
{
  const char *value = std::getenv(name);

  if (value == nullptr || std::string(value).empty()) {
    throw std::runtime_error(
      std::string("Required environment variable is not set: ") + name);
  }

  return value;
}

}  // namespace

class FakeDataGenerator : public rclcpp::Node
{
public:
  using DeviceCommand =
    vagotec_iot_interfaces::srv::DeviceCommand;

  FakeDataGenerator()
  : Node("vagotec_ros2_fake_data_generator"),
    topic_(require_env("ROS2_TOPIC")),
    command_service_name_(require_env("ROS2_COMMAND_SERVICE")),
    device_id_(require_env("DEVICE_ID")),
    publish_interval_seconds_(
      std::stod(require_env("PUBLISH_INTERVAL_SECONDS")))
  {
    if (publish_interval_seconds_ <= 0.0) {
      throw std::runtime_error(
        "PUBLISH_INTERVAL_SECONDS must be greater than zero.");
    }

    publisher_ =
      create_publisher<std_msgs::msg::String>(topic_, 10);

    const auto interval =
      std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::duration<double>(
        publish_interval_seconds_));

    timer_ = create_wall_timer(
      interval,
      std::bind(
        &FakeDataGenerator::publish_telemetry,
        this));

    command_service_ =
      create_service<DeviceCommand>(
      command_service_name_,
      std::bind(
        &FakeDataGenerator::handle_command,
        this,
        std::placeholders::_1,
        std::placeholders::_2));

    RCLCPP_INFO(
      get_logger(),
      "Fake data generator started: "
      "topic=%s device_id=%s interval=%.2f s command_service=%s",
      topic_.c_str(),
      device_id_.c_str(),
      publish_interval_seconds_,
      command_service_name_.c_str());
  }

private:
  void publish_telemetry()
  {
    const double phase =
      static_cast<double>(sequence_) * 0.2;

    const double temperature =
      22.0 + std::sin(phase) * 2.0;

    const double humidity =
      48.0 + std::cos(phase) * 5.0;

    std::ostringstream payload;

    payload << std::fixed << std::setprecision(2)
            << "{"
            << "\"device_id\":\""
            << device_id_
            << "\","
            << "\"temperature_c\":"
            << temperature
            << ","
            << "\"humidity_percent\":"
            << humidity
            << "}";

    std_msgs::msg::String message;
    message.data = payload.str();

    publisher_->publish(message);

    RCLCPP_INFO(
      get_logger(),
      "Published: %s",
      message.data.c_str());

    ++sequence_;
  }

  void handle_command(
    const std::shared_ptr<DeviceCommand::Request> request,
    std::shared_ptr<DeviceCommand::Response> response)
  {
    RCLCPP_INFO(
      get_logger(),
      "Device command received: command=%s value=%s",
      request->command.c_str(),
      request->value.c_str());

    if (request->command == "test") {
      response->success = true;
      response->status = "executed";
      response->message =
        "Simulator executed command 'test' with value '" +
        request->value + "'";

      RCLCPP_INFO(
        get_logger(),
        "Device command executed: %s",
        response->message.c_str());

      return;
    }

    response->success = false;
    response->status = "rejected";
    response->message =
      "Unsupported command: " + request->command;

    RCLCPP_WARN(
      get_logger(),
      "Device command rejected: %s",
      response->message.c_str());
  }

  std::string topic_;
  std::string command_service_name_;
  std::string device_id_;
  double publish_interval_seconds_;
  std::uint64_t sequence_{0};

  rclcpp::Publisher<std_msgs::msg::String>::SharedPtr
    publisher_;

  rclcpp::TimerBase::SharedPtr timer_;

  rclcpp::Service<DeviceCommand>::SharedPtr
    command_service_;
};

int main(int argc, char *argv[])
{
  rclcpp::init(argc, argv);

  try {
    rclcpp::spin(
      std::make_shared<FakeDataGenerator>());
  } catch (const std::exception &error) {
    RCLCPP_FATAL(
      rclcpp::get_logger(
        "vagotec_ros2_fake_data_generator"),
      "%s",
      error.what());

    rclcpp::shutdown();
    return 1;
  }

  rclcpp::shutdown();
  return 0;
}
