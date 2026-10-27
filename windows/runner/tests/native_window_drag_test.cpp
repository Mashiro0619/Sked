#include <windows.h>
#include <windowsx.h>

#include <iostream>

#include "native_window_drag.h"

namespace {
bool received = false;
bool current_position = false;
bool caption = false;
bool capture_released = false;
LRESULT CALLBACK Probe(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCLBUTTONDOWN) {
    POINT cursor = {};
    received = true;
    current_position = GetCursorPos(&cursor) && cursor.x == GET_X_LPARAM(lparam) &&
                       cursor.y == GET_Y_LPARAM(lparam);
    caption = wparam == HTCAPTION;
    capture_released = GetCapture() == nullptr;
    return 0;  // Observe the request without entering a real interactive drag.
  }
  return DefWindowProcW(window, message, wparam, lparam);
}
}  // namespace

int main() {
  WNDCLASSW window_class = {};
  window_class.lpfnWndProc = Probe;
  window_class.hInstance = GetModuleHandleW(nullptr);
  window_class.lpszClassName = L"SkedIsolatedDragProbe";
  RegisterClassW(&window_class);
  HWND window = CreateWindowExW(0, window_class.lpszClassName, L"Sked isolated drag test",
                                 WS_OVERLAPPEDWINDOW, 40, 40, 400, 300,
                                 nullptr, nullptr, window_class.hInstance, nullptr);
  SetCapture(window);
  const bool started = StartNativeCaptionDrag(window);
  const bool rejected_invalid = !StartNativeCaptionDrag(nullptr);
  DestroyWindow(window);
  UnregisterClassW(window_class.lpszClassName, window_class.hInstance);
  const bool results[] = {started && received, current_position, caption,
                          capture_released, rejected_invalid};
  const char* labels[] = {"sends native drag request", "uses current cursor position",
                          "targets the native caption", "releases Flutter capture first",
                          "rejects an invalid target window"};
  int failures = 0;
  for (int index = 0; index < 5; ++index) {
    std::cout << (results[index] ? "PASS " : "FAIL ") << labels[index] << '\n';
    failures += results[index] ? 0 : 1;
  }
  std::cout << "5 checks; " << failures << " failures\n";
  return failures == 0 ? 0 : 1;
}
