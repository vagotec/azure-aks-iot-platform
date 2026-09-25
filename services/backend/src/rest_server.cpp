#include "rest_server.hpp"

#include <stdexcept>
#include <utility>

RestServer::RestServer(
  const std::string &host,
  int port,
  SharedState &shared_state,
  std::function<void(const std::string &)> command_handler)
: host_(host),
  port_(port),
  shared_state_(shared_state),
  command_handler_(std::move(command_handler))
{
  if (host_.empty()) {
    throw std::runtime_error("REST host must not be empty.");
  }

  if (port_ < 1 || port_ > 65535) {
    throw std::runtime_error("REST port must be between 1 and 65535.");
  }

  configure_routes();
}

RestServer::~RestServer()
{
  stop();
}

void RestServer::configure_routes()
{
  server_.Get(
    "/api/health",
    [](const httplib::Request &, httplib::Response &response) {
      response.status = 200;
      response.set_content(
        R"({"status":"ok","service":"vagotec_backend_service"})",
        "application/json");
    });

  server_.Get(
    "/api/telemetry/latest",
    [this](const httplib::Request &, httplib::Response &response) {
      const auto telemetry = shared_state_.get_latest_telemetry();

      if (!telemetry.has_value()) {
        response.status = 503;
        response.set_content(
          R"({"error":"telemetry_not_available"})",
          "application/json");
        return;
      }

      response.status = 200;
      response.set_content(
        telemetry.value(),
        "application/json");
    });

  server_.Post(
    "/api/commands",
    [this](const httplib::Request &request, httplib::Response &response) {
      if (request.body.empty()) {
        response.status = 400;
        response.set_content(
          R"({"error":"empty_command"})",
          "application/json");
        return;
      }

      if (!command_handler_) {
        response.status = 503;
        response.set_content(
          R"({"error":"command_handler_unavailable"})",
          "application/json");
        return;
      }

      try {
        command_handler_(request.body);

        response.status = 202;
        response.set_content(
          R"({"status":"accepted"})",
          "application/json");
      } catch (const std::exception &) {
        response.status = 500;
        response.set_content(
          R"({"error":"command_publish_failed"})",
          "application/json");
      }
    });
}

void RestServer::start()
{
  if (running_.exchange(true)) {
    return;
  }

  server_thread_ = std::thread(
    [this]() {
      const bool result = server_.listen(host_, port_);
      running_.store(false);

      if (!result && !server_.is_running()) {
        // listen() also returns false when stop() intentionally terminates
        // the server, so startup validation is performed by the caller/tests.
      }
    });
}

void RestServer::stop()
{
  if (!running_.load() && !server_thread_.joinable()) {
    return;
  }

  server_.stop();

  if (server_thread_.joinable()) {
    server_thread_.join();
  }

  running_.store(false);
}
