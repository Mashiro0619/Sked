#ifndef RUNNER_DESKTOP_CLIPBOARD_READER_H_
#define RUNNER_DESKTOP_CLIPBOARD_READER_H_

#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>

class DesktopClipboardReader {
 public:
  DesktopClipboardReader(HWND window, flutter::BinaryMessenger* messenger);
  ~DesktopClipboardReader();

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_DESKTOP_CLIPBOARD_READER_H_
