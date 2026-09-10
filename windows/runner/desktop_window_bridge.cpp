#include "desktop_window_bridge.h"
#include <dwmapi.h>
#include <windowsx.h>
#include <algorithm>
#include <cmath>

namespace { constexpr UINT_PTR kWindowSubclassId = 0x534b4544; }

DesktopWindowBridge::DesktopWindowBridge(HWND window, HWND view,
    flutter::BinaryMessenger* messenger) : window_(window), view_(view) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.mashiro.sked/window", &flutter::StandardMethodCodec::GetInstance());
  SetWindowSubclass(view_, ViewProc, kWindowSubclassId, reinterpret_cast<DWORD_PTR>(this));
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto& method = call.method_name();
    if (method == "configureChrome") {
      const auto* args = call.arguments()
          ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
      auto number = [&](const char* key) -> double {
        if (!args) return 0;
        auto item = args->find(flutter::EncodableValue(key));
        if (item == args->end()) return 0;
        if (auto value = std::get_if<double>(&item->second)) return *value;
        if (auto value = std::get_if<int32_t>(&item->second)) return *value;
        if (auto value = std::get_if<int64_t>(&item->second)) return static_cast<double>(*value);
        return 0;
      };
      const double left = number("maximizeLeft"), top = number("maximizeTop"),
          width = number("maximizeWidth"), height = number("maximizeHeight");
      if (!args || !std::isfinite(left) || !std::isfinite(top) ||
          !std::isfinite(width) || !std::isfinite(height) || left < 0 || top < 0 ||
          width <= 0 || height <= 0) {
        maximize_width_ = maximize_height_ = 0;
        result->Error("invalid_chrome", "Expected finite, positive caption geometry");
        return;
      }
      maximize_left_ = left;
      maximize_top_ = top;
      maximize_width_ = width;
      maximize_height_ = height;
      result->Success(); return;
    }
    if (method == "getState") { result->Success(flutter::EncodableValue(State())); return; }
    if (method == "initialize") {
      enabled_ = true;
      MARGINS margins = {1, 1, 1, 1};
      DwmExtendFrameIntoClientArea(window_, &margins);
      SetWindowPos(window_, nullptr, 0, 0, 0, 0,
          SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
      result->Success(flutter::EncodableValue(State()));
      return;
    }
    if (method == "minimize") ShowWindow(window_, SW_MINIMIZE);
    else if (method == "toggleMaximize") ShowWindow(window_, IsZoomed(window_) ? SW_RESTORE : SW_MAXIMIZE);
    else if (method == "startDrag") {
      ReleaseCapture();
      SendMessage(window_, WM_NCLBUTTONDOWN, HTCAPTION, GetMessagePos());
    } else if (method == "confirmClose") {
      allow_close_ = true;
      PostMessage(window_, WM_CLOSE, 0, 0);
    } else if (method == "systemMenu") {
      POINT point; GetCursorPos(&point);
      const auto command = TrackPopupMenu(GetSystemMenu(window_, FALSE),
          TPM_RETURNCMD | TPM_RIGHTBUTTON, point.x, point.y, 0, window_, nullptr);
      if (command) PostMessage(window_, WM_SYSCOMMAND, command, 0);
    } else { result->NotImplemented(); return; }
    result->Success();
  });
}

DesktopWindowBridge::~DesktopWindowBridge() {
  channel_->SetMethodCallHandler(nullptr);
  if (IsWindow(view_)) RemoveWindowSubclass(view_, ViewProc, kWindowSubclassId);
}

flutter::EncodableMap DesktopWindowBridge::State() const {
  return {{flutter::EncodableValue("maximized"), flutter::EncodableValue(IsZoomed(window_) != FALSE)},
          {flutter::EncodableValue("maximizeHovered"), flutter::EncodableValue(maximize_hovered_)},
          {flutter::EncodableValue("focused"), flutter::EncodableValue(GetForegroundWindow() == window_)}};
}
void DesktopWindowBridge::EmitState() {
  if (enabled_) channel_->InvokeMethod("state", std::make_unique<flutter::EncodableValue>(State()));
}

LRESULT DesktopWindowBridge::HitTest(LPARAM lparam) const {
  POINT p = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
  ScreenToClient(window_, &p);
  RECT rect; GetClientRect(window_, &rect);
  const UINT dpi = GetDpiForWindow(window_);
  const int border = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
      GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
  if (!IsZoomed(window_)) {
    const bool left = p.x < border, right = p.x >= rect.right - border;
    const bool top = p.y < border, bottom = p.y >= rect.bottom - border;
    if (top && left) return HTTOPLEFT;
    if (top && right) return HTTOPRIGHT;
    if (bottom && left) return HTBOTTOMLEFT;
    if (bottom && right) return HTBOTTOMRIGHT;
    if (top) return HTTOP;
    if (bottom) return HTBOTTOM;
    if (left) return HTLEFT;
    if (right) return HTRIGHT;
  }
  const double x = p.x * 96.0 / dpi, y = p.y * 96.0 / dpi;
  if (maximize_width_ > 0 && x >= maximize_left_ &&
      x < maximize_left_ + maximize_width_ && y >= maximize_top_ &&
      y < maximize_top_ + maximize_height_)
    return HTMAXBUTTON; // Geometry is measured by the Flutter chrome, including text scaling.
  return HTCLIENT;
}

LRESULT CALLBACK DesktopWindowBridge::ViewProc(HWND hwnd, UINT message,
    WPARAM wparam, LPARAM lparam, UINT_PTR id, DWORD_PTR data) {
  auto self = reinterpret_cast<DesktopWindowBridge*>(data);
  if (message == WM_NCHITTEST && self->enabled_ && self->HitTest(lparam) != HTCLIENT)
    return HTTRANSPARENT; // Let the parent own native edges and caption hit tests.
  if (message == WM_NCDESTROY) RemoveWindowSubclass(hwnd, ViewProc, id);
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

std::optional<LRESULT> DesktopWindowBridge::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (!enabled_) return std::nullopt;
  switch (message) {
    case WM_NCCALCSIZE:
      if (wparam) {
        auto p = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
        if (IsZoomed(window_)) {
          const UINT dpi = GetDpiForWindow(window_);
          const int inset = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) + GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
          InflateRect(&p->rgrc[0], -inset, -inset);
        }
        return 0;
      }
      break;
    case WM_NCHITTEST: return HitTest(lparam);
    case WM_NCMOUSEMOVE: {
      const bool hovered = wparam == HTMAXBUTTON;
      if (hovered != maximize_hovered_) { maximize_hovered_ = hovered; EmitState(); }
      TRACKMOUSEEVENT tracking = {sizeof(TRACKMOUSEEVENT), TME_LEAVE | TME_NONCLIENT, window_, 0};
      TrackMouseEvent(&tracking);
      // Flutter may consume non-client mouse messages. The shell must observe
      // the actual hover stream, not just our HTMAXBUTTON probe, for Snap Layouts.
      LRESULT result = 0;
      if (DwmDefWindowProc(window_, message, wparam, lparam, &result)) return result;
      return DefWindowProc(window_, message, wparam, lparam);
    }
    case WM_NCMOUSELEAVE:
      if (maximize_hovered_) { maximize_hovered_ = false; EmitState(); }
      [[fallthrough]];
    case WM_NCMOUSEHOVER: {
      LRESULT result = 0;
      if (DwmDefWindowProc(window_, message, wparam, lparam, &result)) return result;
      return DefWindowProc(window_, message, wparam, lparam);
    }
    case WM_NCLBUTTONDOWN:
      if (wparam == HTMAXBUTTON) { maximize_pressed_ = true; return 0; }
      break;
    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON && maximize_pressed_) {
        maximize_pressed_ = false;
        ShowWindow(window_, IsZoomed(window_) ? SW_RESTORE : SW_MAXIMIZE);
        return 0;
      }
      maximize_pressed_ = false;
      break;
    case WM_CLOSE:
      if (!allow_close_) { channel_->InvokeMethod("closeRequested", nullptr); return 0; }
      break;
    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = GetDpiForWindow(window_);
      info->ptMinTrackSize = {MulDiv(330, dpi, 96), MulDiv(320, dpi, 96)};
      return 0;
    }
    case WM_SIZE:
    case WM_ACTIVATE:
    case WM_DPICHANGED: EmitState(); break;
  }
  return std::nullopt;
}
