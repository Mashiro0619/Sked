#ifndef RUNNER_NATIVE_WINDOW_DRAG_H_
#define RUNNER_NATIVE_WINDOW_DRAG_H_

#include <windows.h>

inline bool StartNativeCaptionDrag(HWND window) {
  POINT cursor = {};
  if (!IsWindow(window) || !GetCursorPos(&cursor)) return false;
  ReleaseCapture();
  // A Flutter platform message can arrive after other window messages. Use
  // the current pointer rather than the last dequeued message's position.
  SendMessageW(window, WM_NCLBUTTONDOWN, HTCAPTION,
               MAKELPARAM(cursor.x, cursor.y));
  return true;
}

#endif  // RUNNER_NATIVE_WINDOW_DRAG_H_
