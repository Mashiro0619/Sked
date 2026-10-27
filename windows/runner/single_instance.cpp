#include "single_instance.h"

#include <commctrl.h>

#include <algorithm>
#include <utility>

std::wstring DefaultWindowsInstanceNamespace() {
#ifdef SKED_WINDOWS_TEST_NAMESPACE
  const std::string name = SKED_WINDOWS_TEST_NAMESPACE;
  return L"Mashiro.Sked.Tests." + std::wstring(name.begin(), name.end());
#else
  return L"Mashiro.Sked.MainWindow";
#endif
}

bool IsNotificationComServerLaunch(const std::vector<std::string>& arguments) {
  bool activation_server = false;
  bool embedding = false;
  for (const auto& argument : arguments) {
    activation_server |= argument.find("AppNotificationActivationServer") !=
                         std::string::npos;
    embedding |= _stricmp(argument.c_str(), "-Embedding") == 0;
  }
  return activation_server && embedding;
}

SingleInstance::SingleInstance(std::wstring name)
    : name_(std::move(name)), property_name_(name_ + L".Window") {
  activation_message_ = RegisterWindowMessageW((name_ + L".Activate").c_str());
}

SingleInstance::~SingleInstance() {
  if (window_ && IsWindow(window_)) {
    RemoveWindowSubclass(window_, WindowProc, reinterpret_cast<UINT_PTR>(this));
    RemovePropW(window_, property_name_.c_str());
  }
  if (mutex_) {
    if (owns_mutex_) ReleaseMutex(mutex_);
    CloseHandle(mutex_);
  }
}

HWND SingleInstance::FindExistingWindow() const {
  struct Search { const wchar_t* property; HWND found; } search = {
      property_name_.c_str(), nullptr};
  EnumWindows([](HWND window, LPARAM data) -> BOOL {
    auto* context = reinterpret_cast<Search*>(data);
    if (!GetPropW(window, context->property)) return TRUE;
    context->found = window;
    return FALSE;
  }, reinterpret_cast<LPARAM>(&search));
  return search.found;
}

InstanceDisposition SingleInstance::AcquireOrActivate(bool notification_activation,
                                                     DWORD wait_millis) {
  if (!activation_message_) return InstanceDisposition::unavailable;
  mutex_ = CreateMutexW(nullptr, TRUE, (L"Local\\" + name_).c_str());
  if (!mutex_) return InstanceDisposition::unavailable;
  const bool already_exists = GetLastError() == ERROR_ALREADY_EXISTS;
  if (!already_exists) {
    owns_mutex_ = true;
    return InstanceDisposition::primary;
  }
  auto ownership = WaitForSingleObject(mutex_, 0);
  if (ownership == WAIT_OBJECT_0 || ownership == WAIT_ABANDONED) {
    owns_mutex_ = true;
    return InstanceDisposition::primary;
  }
  // COM startup arguments are not the notification payload. Keep its existing
  // activation path alive until the plugin receives the actual COM callback.
  if (notification_activation) return InstanceDisposition::notification_activation;

  const ULONGLONG deadline = GetTickCount64() + wait_millis;
  do {
    const HWND existing = FindExistingWindow();
    if (existing) {
      DWORD process_id = 0;
      GetWindowThreadProcessId(existing, &process_id);
      AllowSetForegroundWindow(process_id);
      DWORD_PTR result = 0;
      if (SendMessageTimeoutW(existing, activation_message_, 0, 0,
                              SMTO_ABORTIFHUNG | SMTO_BLOCK, 1000, &result)) {
        return InstanceDisposition::activated_existing;
      }
    }
    const auto now = GetTickCount64();
    if (now >= deadline) break;
    ownership = WaitForSingleObject(
        mutex_, static_cast<DWORD>(std::min<ULONGLONG>(50, deadline - now)));
    if (ownership == WAIT_OBJECT_0 || ownership == WAIT_ABANDONED) {
      owns_mutex_ = true;
      return InstanceDisposition::primary;
    }
    if (ownership == WAIT_FAILED) return InstanceDisposition::unavailable;
  } while (true);
  return InstanceDisposition::existing_not_ready;
}

bool SingleInstance::RegisterWindow(HWND window) {
  if (!owns_mutex_ || !window || !IsWindow(window)) return false;
  if (!SetPropW(window, property_name_.c_str(), reinterpret_cast<HANDLE>(this))) {
    return false;
  }
  if (!SetWindowSubclass(window, WindowProc, reinterpret_cast<UINT_PTR>(this),
                          reinterpret_cast<DWORD_PTR>(this))) {
    RemovePropW(window, property_name_.c_str());
    return false;
  }
  window_ = window;
  return true;
}

LRESULT CALLBACK SingleInstance::WindowProc(HWND window, UINT message,
                                            WPARAM wparam, LPARAM lparam,
                                            UINT_PTR id, DWORD_PTR data) {
  auto* self = reinterpret_cast<SingleInstance*>(data);
  if (message == self->activation_message_) {
    if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
    else if (!IsWindowVisible(window)) ShowWindow(window, SW_SHOW);
    if (!SetForegroundWindow(window)) {
      FLASHWINFO flash = {sizeof(FLASHWINFO), window, FLASHW_TRAY, 2, 0};
      FlashWindowEx(&flash);
    }
    return 1;
  }
  if (message == WM_NCDESTROY) {
    RemovePropW(window, self->property_name_.c_str());
    RemoveWindowSubclass(window, WindowProc, id);
    self->window_ = nullptr;
  }
  return DefSubclassProc(window, message, wparam, lparam);
}
