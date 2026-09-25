#ifndef VAGOTEC_BACKEND_SERVICE__REST_SERVER_HPP_
#define VAGOTEC_BACKEND_SERVICE__REST_SERVER_HPP_

#include <atomic>
#include <functional>
#include <memory>
#include <string>
#include <thread>

#include <httplib.h>

#include "shared_state.hpp"

class RestServer
{
public:
  using CommandHandler =
    std::function<std::string(const std::string &)>;

  RestServer(
    const std::string &host,
    int port,
    SharedState &shared_state,
    CommandHandler command_handler);

  ~RestServer();

  RestServer(const RestServer &) = delete;
  RestServer &operator=(const RestServer &) = delete;

  void start();
  void stop();

private:
  void configure_routes();

  std::string host_;
  int port_;

  SharedState &shared_state_;
  CommandHandler command_handler_;

  httplib::Server server_;
  std::thread server_thread_;
  std::atomic<bool> running_{false};
};

#endif
