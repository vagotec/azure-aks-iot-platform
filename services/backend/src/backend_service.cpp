#include <cstdlib>
#include <memory>
#include <stdexcept>
#include <string>

#include "mqtt/async_client.h"
#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/string.hpp"
#include "rest_server.hpp"
#include "shared_state.hpp"

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

int require_int_env(const char *name)
{
  const std::string value = require_env(name);

  try {
    return std::stoi(value);
  } catch (const std::exception &) {
    throw std::runtime_error(
      std::string("Environment variable must be an integer: ") + name);
  }
}

}  // namespace

class BackendService : public rclcpp::Node, public virtual mqtt::callback
{
public:
  BackendService()
  : Node("vagotec_backend_service"),
    ros2_topic_(require_env("ROS2_TOPIC")),
    ros2_command_topic_(require_env("ROS2_COMMAND_TOPIC")),
    mqtt_host_(require_env("MQTT_HOST")),
    mqtt_port_(require_int_env("MQTT_PORT")),
    mqtt_topic_(require_env("MQTT_TOPIC")),
    mqtt_command_topic_(require_env("MQTT_COMMAND_TOPIC")),
    mqtt_client_id_(require_env("MQTT_CLIENT_ID")),
    mqtt_qos_(require_int_env("MQTT_QOS")),
    rest_host_(require_env("REST_HOST")),
    rest_port_(require_int_env("REST_PORT")),
    mqtt_server_uri_(
      "tcp://" + mqtt_host_ + ":" + std::to_string(mqtt_port_)),
    mqtt_client_(
      mqtt_server_uri_,
      mqtt_client_id_,
      mqtt::create_options(MQTTVERSION_5))
  {
    if (mqtt_port_ < 1 || mqtt_port_ > 65535) {
      throw std::runtime_error("MQTT_PORT must be between 1 and 65535.");
    }

    if (mqtt_qos_ < 0 || mqtt_qos_ > 2) {
      throw std::runtime_error("MQTT_QOS must be 0, 1, or 2.");
    }

    // Register the callback before connecting so both the initial
    // connection and automatic reconnects can restore subscriptions.
    mqtt_client_.set_callback(*this);

    connect_mqtt();

    command_publisher_ = create_publisher<std_msgs::msg::String>(
      ros2_command_topic_, 10);

    subscription_ = create_subscription<std_msgs::msg::String>(
      ros2_topic_,
      10,
      [this](const std_msgs::msg::String::SharedPtr message) {
        handle_telemetry(message);
      });

    rest_server_ = std::make_unique<RestServer>(
      rest_host_,
      rest_port_,
      shared_state_,
      [this](const std::string &payload) {
        publish_ros_command(payload, "HTTP REST");
      });
    rest_server_->start();

    RCLCPP_INFO(
      get_logger(),
      "REST API started: http://%s:%d",
      rest_host_.c_str(),
      rest_port_);

    RCLCPP_INFO(
      get_logger(),
      "C++ Backend Service started: ROS2=%s MQTT=%s topic=%s QoS=%d",
      ros2_topic_.c_str(),
      mqtt_server_uri_.c_str(),
      mqtt_topic_.c_str(),
      mqtt_qos_);
  }

  ~BackendService() override
  {
    try {
      if (mqtt_client_.is_connected()) {
        mqtt_client_.disconnect()->wait();
      }
    } catch (const mqtt::exception &error) {
      RCLCPP_ERROR(
        get_logger(),
        "MQTT disconnect failed: %s",
        error.what());
    }
  }

private:
  void connect_mqtt()
  {
    mqtt::connect_options connect_options;

    connect_options.set_mqtt_version(MQTTVERSION_5);
    connect_options.set_clean_start(true);
    connect_options.set_automatic_reconnect(true);

    RCLCPP_INFO(
      get_logger(),
      "Connecting to MQTT 5 broker: %s",
      mqtt_server_uri_.c_str());

    mqtt_client_.connect(connect_options)->wait();

    RCLCPP_INFO(
      get_logger(),
      "Connected to MQTT 5 broker.");
  }

  void connected(const std::string &cause) override
  {
    RCLCPP_INFO(
      get_logger(),
      "MQTT connection established%s%s",
      cause.empty() ? "" : ": ",
      cause.c_str());

    try {
      mqtt_client_.subscribe(mqtt_command_topic_, mqtt_qos_);

      RCLCPP_INFO(
        get_logger(),
        "MQTT command subscription requested: topic=%s QoS=%d",
        mqtt_command_topic_.c_str(),
        mqtt_qos_);
    } catch (const mqtt::exception &error) {
      RCLCPP_ERROR(
        get_logger(),
        "MQTT command subscription request failed: %s",
        error.what());
    }
  }

  void message_arrived(mqtt::const_message_ptr message) override
  {
    if (message->get_topic() != mqtt_command_topic_) {
      return;
    }

    publish_ros_command(message->to_string(), "MQTT 5");
  }

  void publish_ros_command(
    const std::string &payload,
    const std::string &source)
  {
    std_msgs::msg::String ros_message;
    ros_message.data = payload;

    command_publisher_->publish(ros_message);

    RCLCPP_INFO(
      get_logger(),
      "%s -> ROS 2: ros2_topic=%s payload=%s",
      source.c_str(),
      ros2_command_topic_.c_str(),
      payload.c_str());
  }

  void handle_telemetry(
    const std_msgs::msg::String::SharedPtr message)
  {
    // Store the latest ROS 2 telemetry independently of MQTT availability.
    // The REST API can therefore expose the most recently received
    // edge telemetry without coupling HTTP reads to the MQTT broker.
    shared_state_.set_latest_telemetry(message->data);

    if (!mqtt_client_.is_connected()) {
      RCLCPP_ERROR(
        get_logger(),
        "MQTT broker is not connected. Telemetry not published.");
      return;
    }

    try {
      auto mqtt_message = mqtt::make_message(
        mqtt_topic_,
        message->data);

      mqtt_message->set_qos(mqtt_qos_);
      mqtt_message->set_retained(false);

      mqtt_client_.publish(mqtt_message);

      RCLCPP_INFO(
        get_logger(),
        "ROS 2 -> MQTT 5: topic=%s payload=%s",
        mqtt_topic_.c_str(),
        message->data.c_str());
    } catch (const mqtt::exception &error) {
      RCLCPP_ERROR(
        get_logger(),
        "MQTT publish failed: %s",
        error.what());
    }
  }

  std::string ros2_topic_;
  std::string ros2_command_topic_;

  std::string mqtt_host_;
  int mqtt_port_;
  std::string mqtt_topic_;
  std::string mqtt_command_topic_;
  std::string mqtt_client_id_;
  int mqtt_qos_;
  std::string mqtt_server_uri_;

  std::string rest_host_;
  int rest_port_;

  SharedState shared_state_;
  std::unique_ptr<RestServer> rest_server_;

  mqtt::async_client mqtt_client_;

  rclcpp::Subscription<std_msgs::msg::String>::SharedPtr subscription_;
  rclcpp::Publisher<std_msgs::msg::String>::SharedPtr command_publisher_;
};

int main(int argc, char *argv[])
{
  rclcpp::init(argc, argv);

  try {
    rclcpp::spin(std::make_shared<BackendService>());
  } catch (const std::exception &error) {
    RCLCPP_FATAL(
      rclcpp::get_logger("vagotec_backend_service"),
      "%s",
      error.what());

    rclcpp::shutdown();
    return 1;
  }

  rclcpp::shutdown();
  return 0;
}
