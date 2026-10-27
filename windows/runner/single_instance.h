#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include <string>
#include <vector>

enum class InstanceDisposition {
  primary,
  activated_existing,
  existing_not_ready,
  notification_activation,
  unavailable,
};

std::wstring DefaultWindowsInstanceNamespace();
bool IsNotificationComServerLaunch(const std::vector<std::string>& arguments);

// A process-lifetime mutex is an activation optimization. The Dart data lease
// remains authoritative when native discovery is unavailable or races exit.
class SingleInstance {
 public:
  explicit SingleInstance(std::wstring name);
  ~SingleInstance();
  SingleInstance(const SingleInstance&) = delete;
  SingleInstance& operator=(const SingleInstance&) = delete;

  InstanceDisposition AcquireOrActivate(bool notification_activation = false,
                                       DWORD wait_millis = 3000);
  bool RegisterWindow(HWND window);

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam, UINT_PTR id, DWORD_PTR data);
  HWND FindExistingWindow() const;

  std::wstring name_;
  std::wstring property_name_;
  UINT activation_message_ = 0;
  HANDLE mutex_ = nullptr;
  bool owns_mutex_ = false;
  HWND window_ = nullptr;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
