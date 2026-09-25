#ifndef VAGOTEC_BACKEND_SERVICE__SHARED_STATE_HPP_
#define VAGOTEC_BACKEND_SERVICE__SHARED_STATE_HPP_

#include <mutex>
#include <optional>
#include <string>

class SharedState
{
public:
  void set_latest_telemetry(const std::string &telemetry)
  {
    std::lock_guard<std::mutex> lock(mutex_);
    latest_telemetry_ = telemetry;
  }

  std::optional<std::string> get_latest_telemetry() const
  {
    std::lock_guard<std::mutex> lock(mutex_);
    return latest_telemetry_;
  }

private:
  mutable std::mutex mutex_;
  std::optional<std::string> latest_telemetry_;
};

#endif  // VAGOTEC_BACKEND_SERVICE__SHARED_STATE_HPP_
