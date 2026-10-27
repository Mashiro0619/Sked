#include <windows.h>

#include <iostream>
#include <string>

#include "single_instance.h"

namespace {
int failures = 0;
int checks = 0;
void Check(bool value, const char* name) {
  ++checks;
  std::cout << (value ? "PASS " : "FAIL ") << name << '\n';
  if (!value) ++failures;
}
PROCESS_INFORMATION Child(const std::wstring& mode, const std::wstring& name) {
  wchar_t executable[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, executable, MAX_PATH);
  std::wstring command = L"\"" + std::wstring(executable) + L"\" " + mode + L" " + name;
  STARTUPINFOW startup = {sizeof(STARTUPINFOW)};
  PROCESS_INFORMATION process = {};
  if (!CreateProcessW(executable, command.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    Check(false, "launch child process");
  }
  return process;
}
DWORD WaitAndPump(HANDLE process) {
  const auto deadline = GetTickCount64() + 6000;
  while (WaitForSingleObject(process, 0) == WAIT_TIMEOUT && GetTickCount64() < deadline) {
    MSG message;
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
      TranslateMessage(&message);
      DispatchMessageW(&message);
    }
    Sleep(5);
  }
  DWORD code = STILL_ACTIVE;
  GetExitCodeProcess(process, &code);
  return code;
}
void CloseChild(PROCESS_INFORMATION process) {
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
}
}  // namespace

int wmain(int argc, wchar_t** argv) {
  if (argc == 3) {
    SingleInstance instance(argv[2]);
    const bool hold = std::wstring(argv[1]) == L"--hold";
    const auto result = instance.AcquireOrActivate();
    if (!hold) return result == InstanceDisposition::activated_existing ? 0 : 3;
    if (result != InstanceDisposition::primary) return 4;
    HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, (std::wstring(argv[2]) + L".Ready").c_str());
    SetEvent(ready);
    CloseHandle(ready);
    Sleep(INFINITE);
    return 5;
  }
  const std::wstring name = L"Mashiro.Sked.Tests.Instance." + std::to_wstring(GetCurrentProcessId());
  Check(IsNotificationComServerLaunch({"----AppNotificationActivationServer", "-Embedding"}),
        "notification COM server launch is recognized");
  Check(!IsNotificationComServerLaunch({"-Embedding"}) && !IsNotificationComServerLaunch({}),
        "normal launches retain single-instance activation");
  SingleInstance primary(name);
  Check(primary.AcquireOrActivate() == InstanceDisposition::primary, "first process owns mutex");
  HWND window = CreateWindowExW(0, L"STATIC", L"Sked isolated activation test",
                                 WS_OVERLAPPEDWINDOW, 100, 100, 500, 350,
                                 nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  Check(primary.RegisterWindow(window), "only the owner registers the target window");
  ShowWindow(window, SW_SHOWNORMAL);
  ShowWindow(window, SW_MINIMIZE);
  auto second = Child(L"--activate", name);
  Check(WaitAndPump(second.hProcess) == 0, "second process activates then exits successfully");
  Check(!IsIconic(window), "activation restores the minimized window");
  Check(GetForegroundWindow() == window, "activation foregrounds the existing window");
  CloseChild(second);
  DestroyWindow(window);

  const std::wstring crash_name = name + L".Crash";
  HANDLE ready = CreateEventW(nullptr, TRUE, FALSE, (crash_name + L".Ready").c_str());
  auto holder = Child(L"--hold", crash_name);
  Check(WaitForSingleObject(ready, 5000) == WAIT_OBJECT_0, "separate process holds startup mutex");
  SingleInstance waiting(crash_name);
  Check(waiting.AcquireOrActivate(false, 50) == InstanceDisposition::existing_not_ready,
        "startup race does not create a second window");
  SingleInstance notification(crash_name);
  Check(notification.AcquireOrActivate(true, 50) == InstanceDisposition::notification_activation,
        "COM callback carrier is not discarded as a normal duplicate");
  TerminateProcess(holder.hProcess, 0);
  WaitForSingleObject(holder.hProcess, 5000);
  SingleInstance recovered(crash_name);
  Check(recovered.AcquireOrActivate() == InstanceDisposition::primary,
        "new process reclaims mutex after prior owner crashes");
  CloseChild(holder);
  CloseHandle(ready);
  std::cout << checks << " checks; " << failures << " failures\n";
  return failures == 0 ? 0 : 1;
}
