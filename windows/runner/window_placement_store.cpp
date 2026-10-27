#include "window_placement_store.h"

#include <cstdint>
#include <utility>

namespace {
constexpr wchar_t kValueName[] = L"Placement";
constexpr DWORD kVersion = 1;
struct StoredPlacement {
  DWORD version = kVersion;
  WINDOWPLACEMENT placement = {sizeof(WINDOWPLACEMENT)};
};

bool HasUsableBounds(const RECT& bounds) {
  const auto width = static_cast<int64_t>(bounds.right) - bounds.left;
  const auto height = static_cast<int64_t>(bounds.bottom) - bounds.top;
  return width >= 100 && height >= 100 && width <= 100000 && height <= 100000;
}
}  // namespace

WindowPlacementStore::WindowPlacementStore(std::wstring registry_path)
    : registry_path_(std::move(registry_path)) {}

std::wstring DefaultWindowPlacementRegistryPath() {
#ifdef SKED_WINDOWS_TEST_NAMESPACE
  const std::string name = SKED_WINDOWS_TEST_NAMESPACE;
  return L"Software\\Mashiro\\Sked.Tests\\" +
         std::wstring(name.begin(), name.end()) + L"\\Window";
#else
  return L"Software\\Mashiro\\Sked\\Window";
#endif
}

bool WindowPlacementStore::Save(HWND window) const {
  StoredPlacement saved;
  if (!GetWindowPlacement(window, &saved.placement) ||
      !HasUsableBounds(saved.placement.rcNormalPosition)) {
    return false;
  }
  // Closing while minimized must reopen visibly and preserve whether the
  // user had maximized the window before minimizing it.
  saved.placement.showCmd =
      saved.placement.showCmd == SW_SHOWMAXIMIZED ||
              (saved.placement.flags & WPF_RESTORETOMAXIMIZED) != 0
          ? SW_SHOWMAXIMIZED
          : SW_SHOWNORMAL;
  saved.placement.flags = 0;
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, registry_path_.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return false;
  }
  const auto result = RegSetValueExW(
      key, kValueName, 0, REG_BINARY, reinterpret_cast<const BYTE*>(&saved),
      sizeof(saved));
  RegCloseKey(key);
  return result == ERROR_SUCCESS;
}

std::optional<int> WindowPlacementStore::RestoreHidden(HWND window) const {
  StoredPlacement saved;
  DWORD size = sizeof(saved);
  if (RegGetValueW(HKEY_CURRENT_USER, registry_path_.c_str(), kValueName,
                   RRF_RT_REG_BINARY, nullptr, &saved, &size) != ERROR_SUCCESS ||
      size != sizeof(saved) || saved.version != kVersion ||
      saved.placement.length != sizeof(WINDOWPLACEMENT) ||
      !HasUsableBounds(saved.placement.rcNormalPosition) ||
      (saved.placement.showCmd != SW_SHOWNORMAL &&
       saved.placement.showCmd != SW_SHOWMAXIMIZED)) {
    return std::nullopt;
  }
  // A disconnected monitor must not leave the application inaccessible. Keep
  // the launch default if the saved rectangle no longer meets any monitor;
  // SetWindowPlacement adjusts partially off-screen rectangles itself.
  if (!MonitorFromRect(&saved.placement.rcNormalPosition,
                       MONITOR_DEFAULTTONULL)) {
    return std::nullopt;
  }
  const int show_command = static_cast<int>(saved.placement.showCmd);
  saved.placement.showCmd = SW_HIDE;
  saved.placement.flags = 0;
  if (!SetWindowPlacement(window, &saved.placement)) return std::nullopt;
  return show_command;
}
