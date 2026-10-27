#ifndef RUNNER_SCHOOL_WEB_SESSION_BRIDGE_H_
#define RUNNER_SCHOOL_WEB_SESSION_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

// Clears the same default WebView2 profile used by the school import browser.
// The Flutter plugin's Windows implementation does not expose profile cleanup.
class SchoolWebSessionBridge {
 public:
  SchoolWebSessionBridge(HWND window, flutter::BinaryMessenger* messenger);
  ~SchoolWebSessionBridge();

 private:
  class ClearOperation;
  HWND window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  std::shared_ptr<ClearOperation> operation_;
};

#endif  // RUNNER_SCHOOL_WEB_SESSION_BRIDGE_H_
