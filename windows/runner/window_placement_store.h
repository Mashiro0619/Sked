#ifndef RUNNER_WINDOW_PLACEMENT_STORE_H_
#define RUNNER_WINDOW_PLACEMENT_STORE_H_

#include <windows.h>

#include <optional>
#include <string>

// Persists native workspace coordinates; never reinterpret them as client or
// DPI-independent coordinates. Callers may supply a separate key for tests.
class WindowPlacementStore {
 public:
  explicit WindowPlacementStore(std::wstring registry_path);

  bool Save(HWND window) const;
  // Restores geometry without displaying an empty Flutter window. The returned
  // command is applied when the first frame is ready.
  std::optional<int> RestoreHidden(HWND window) const;

 private:
  std::wstring registry_path_;
};

std::wstring DefaultWindowPlacementRegistryPath();

#endif  // RUNNER_WINDOW_PLACEMENT_STORE_H_
