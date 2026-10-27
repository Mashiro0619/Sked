#include <windows.h>

#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#include "window_placement_store.h"

namespace {
int failures = 0;
int checks = 0;
void Check(bool condition, const char* label) {
  ++checks;
  if (!condition) { ++failures; std::cerr << "FAIL " << label << '\n'; }
  else { std::cout << "PASS " << label << '\n'; }
}
HWND CreateProbeWindow() {
  return CreateWindowExW(0, L"STATIC", L"Sked isolated placement test",
                         WS_OVERLAPPEDWINDOW, 40, 50, 420, 330,
                         nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
}
WINDOWPLACEMENT Placement(HWND window) {
  WINDOWPLACEMENT placement = {sizeof(WINDOWPLACEMENT)};
  GetWindowPlacement(window, &placement);
  return placement;
}
void WriteBytes(const std::wstring& path, const std::vector<BYTE>& bytes) {
  HKEY key = nullptr;
  RegCreateKeyExW(HKEY_CURRENT_USER, path.c_str(), 0, nullptr, 0,
                  KEY_SET_VALUE, nullptr, &key, nullptr);
  RegSetValueExW(key, L"Placement", 0, REG_BINARY, bytes.data(),
                 static_cast<DWORD>(bytes.size()));
  RegCloseKey(key);
}
}  // namespace

int main() {
  const std::wstring path = L"Software\\Mashiro\\Sked.Tests\\Placement-" +
                           std::to_wstring(GetCurrentProcessId());
  WindowPlacementStore store(path);
  HWND first = CreateProbeWindow();
  HWND second = CreateProbeWindow();
  if (!first || !second) return 2;
  Check(!store.RestoreHidden(second).has_value(), "missing state keeps defaults");

  SetWindowPos(first, nullptr, 200, 150, 700, 500, SWP_NOZORDER | SWP_NOACTIVATE);
  const auto expected = Placement(first).rcNormalPosition;
  Check(store.Save(first), "save native placement");
  Check(store.RestoreHidden(second) == SW_SHOWNORMAL,
        "normal state restores a visible show command");
  const auto restored = Placement(second).rcNormalPosition;
  Check(EqualRect(&expected, &restored) != FALSE,
        "position and size round trip without DPI rescaling");
  Check(!IsWindowVisible(second), "restoration stays hidden until first frame");

  ShowWindow(first, SW_SHOWMAXIMIZED);
  Check(store.Save(first) && store.RestoreHidden(second) == SW_SHOWMAXIMIZED,
        "maximized state survives restart");
  ShowWindow(first, SW_MINIMIZE);
  Check(store.Save(first) && store.RestoreHidden(second) == SW_SHOWMAXIMIZED,
        "minimized maximized window reopens maximized");
  ShowWindow(first, SW_RESTORE);
  ShowWindow(first, SW_SHOWNORMAL);
  ShowWindow(first, SW_MINIMIZE);
  Check(store.Save(first) && store.RestoreHidden(second) == SW_SHOWNORMAL,
        "minimized normal window reopens normally");

  DWORD bytes = 0;
  RegGetValueW(HKEY_CURRENT_USER, path.c_str(), L"Placement", RRF_RT_REG_BINARY,
                nullptr, nullptr, &bytes);
  std::vector<BYTE> saved(bytes);
  RegGetValueW(HKEY_CURRENT_USER, path.c_str(), L"Placement", RRF_RT_REG_BINARY,
                nullptr, saved.data(), &bytes);
  // The persisted record ends with WINDOWPLACEMENT.rcNormalPosition. Simulate
  // a monitor that has been disconnected between the two process launches.
  RECT disconnected = {100000, 100000, 100700, 100500};
  std::memcpy(saved.data() + saved.size() - sizeof(RECT), &disconnected, sizeof(RECT));
  WriteBytes(path, saved);
  Check(!store.RestoreHidden(second).has_value(),
        "missing monitor keeps a reachable launch default");
  WriteBytes(path, {1, 2, 3});
  Check(!store.RestoreHidden(second).has_value(), "truncated state is ignored");
  Check(!store.Save(nullptr), "invalid window cannot overwrite saved state");
  DestroyWindow(first);
  DestroyWindow(second);
  RegDeleteTreeW(HKEY_CURRENT_USER, path.c_str());
  std::cout << checks << " checks; " << failures << " failures\n";
  return failures == 0 ? 0 : 1;
}
