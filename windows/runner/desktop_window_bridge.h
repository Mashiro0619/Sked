#ifndef RUNNER_DESKTOP_WINDOW_BRIDGE_H_
#define RUNNER_DESKTOP_WINDOW_BRIDGE_H_
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <commctrl.h>
#include <memory>
#include <optional>

// Keeps window semantics in Win32; Dart only paints and invokes commands.
class DesktopWindowBridge {
 public:
  DesktopWindowBridge(HWND window, HWND view, flutter::BinaryMessenger* messenger);
  ~DesktopWindowBridge();
  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
 private:
  LRESULT HitTest(LPARAM lparam) const;
  void EmitState();
  flutter::EncodableMap State() const;
  static LRESULT CALLBACK ViewProc(HWND hwnd, UINT message, WPARAM wparam,
      LPARAM lparam, UINT_PTR id, DWORD_PTR data);
  HWND window_;
  HWND view_;
  bool enabled_ = false;
  bool allow_close_ = false;
  bool maximize_pressed_ = false;
  bool maximize_hovered_ = false;
  double maximize_left_ = 0, maximize_top_ = 0, maximize_width_ = 0, maximize_height_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
