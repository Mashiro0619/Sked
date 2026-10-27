#include "school_web_session_bridge.h"

#include <WebView2.h>
#include <flutter/standard_method_codec.h>
#include <wrl.h>

#include <string>
#include <vector>

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

namespace {
using CreateEnvironment = HRESULT(STDAPICALLTYPE*)(
    PCWSTR, PCWSTR, ICoreWebView2EnvironmentOptions*,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler*);

std::wstring LoaderPath() {
  std::vector<wchar_t> path(32768);
  const DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                        static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) return {};
  std::wstring executable(path.data(), length);
  const auto separator = executable.find_last_of(L"\\/");
  if (separator == std::wstring::npos) return {};
  return executable.substr(0, separator + 1) + L"WebView2Loader.dll";
}

std::string Utf8(const wchar_t* source) {
  if (!source) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, source, -1, nullptr, 0,
                                      nullptr, nullptr);
  if (size <= 1) return {};
  std::string output(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, source, -1, output.data(), size, nullptr,
                      nullptr);
  output.resize(static_cast<size_t>(size - 1));
  return output;
}
}  // namespace

class SchoolWebSessionBridge::ClearOperation
    : public std::enable_shared_from_this<ClearOperation> {
 public:
  explicit ClearOperation(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
      : result_(std::move(result)) {}

  ~ClearOperation() {
    Cancel();
    if (loader_) FreeLibrary(loader_);
  }

  bool completed() const { return completed_; }

  void Cancel() {
    completed_ = true;
    result_.reset();
    profile_.Reset();
    webview_.Reset();
    if (controller_) controller_->Close();
    controller_.Reset();
    environment_.Reset();
  }

  void Start(HWND window) {
    const auto path = LoaderPath();
    if (path.empty()) return Complete(E_FAIL);
    loader_ = LoadLibraryExW(path.c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!loader_) return Complete(HRESULT_FROM_WIN32(GetLastError()));
    const auto create = reinterpret_cast<CreateEnvironment>(GetProcAddress(
        loader_, "CreateCoreWebView2EnvironmentWithOptions"));
    if (!create) return Complete(E_NOINTERFACE);

    auto self = shared_from_this();
    // Null options match the default environment used by InAppWebView,
    // including WebView2's package redirection and environment overrides.
    const HRESULT started = create(nullptr, nullptr, nullptr,
        Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
            [self, window](HRESULT error, ICoreWebView2Environment* environment)
                -> HRESULT {
              if (self->completed_) return S_OK;
              if (FAILED(error) || !environment) {
                self->Complete(FAILED(error) ? error : E_FAIL);
                return S_OK;
              }
              self->environment_ = environment;
              ComPtr<ICoreWebView2Environment7> environment7;
              if (SUCCEEDED(environment->QueryInterface(
                      IID_PPV_ARGS(&environment7)))) {
                LPWSTR folder = nullptr;
                if (SUCCEEDED(environment7->get_UserDataFolder(&folder))) {
                  self->user_data_folder_ = Utf8(folder);
                }
                CoTaskMemFree(folder);
              }
              const auto created = environment->CreateCoreWebView2Controller(
                  window,
                  Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                      [self](HRESULT controller_error,
                             ICoreWebView2Controller* controller) -> HRESULT {
                        if (self->completed_) {
                          if (controller) controller->Close();
                          return S_OK;
                        }
                        if (FAILED(controller_error) || !controller) {
                          self->Complete(FAILED(controller_error)
                                             ? controller_error : E_FAIL);
                          return S_OK;
                        }
                        self->controller_ = controller;
                        controller->put_IsVisible(FALSE);
                        HRESULT result = controller->get_CoreWebView2(
                            &self->webview_);
                        ComPtr<ICoreWebView2_13> webview13;
                        if (SUCCEEDED(result)) {
                          result = self->webview_.As(&webview13);
                        }
                        ComPtr<ICoreWebView2Profile> profile;
                        if (SUCCEEDED(result)) {
                          result = webview13->get_Profile(&profile);
                        }
                        if (SUCCEEDED(result)) {
                          result = profile.As(&self->profile_);
                        }
                        if (FAILED(result)) {
                          self->Complete(result);
                          return S_OK;
                        }
                        const auto clearing = self->profile_->ClearBrowsingDataAll(
                            Callback<ICoreWebView2ClearBrowsingDataCompletedHandler>(
                                [self](HRESULT clear_error) -> HRESULT {
                                  self->Complete(clear_error);
                                  return S_OK;
                                }).Get());
                        if (FAILED(clearing)) self->Complete(clearing);
                        return S_OK;
                      }).Get());
              if (FAILED(created)) self->Complete(created);
              return S_OK;
            }).Get());
    if (FAILED(started)) Complete(started);
  }

 private:
  void Complete(HRESULT error) {
    if (completed_) return;
    completed_ = true;
    if (FAILED(error)) {
      result_->Error("school_web_session_clear_failed",
                     "The school browser profile could not be cleared.",
                     flutter::EncodableValue(static_cast<int64_t>(error)));
    } else {
      result_->Success(flutter::EncodableValue(user_data_folder_));
    }
    result_.reset();
    // Keep the hidden controller alive until the callback has returned.
    // The bridge releases the completed operation on the next call or teardown.
  }

  bool completed_ = false;
  HMODULE loader_ = nullptr;
  std::string user_data_folder_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result_;
  ComPtr<ICoreWebView2Environment> environment_;
  ComPtr<ICoreWebView2Controller> controller_;
  ComPtr<ICoreWebView2> webview_;
  ComPtr<ICoreWebView2Profile2> profile_;
};

SchoolWebSessionBridge::SchoolWebSessionBridge(
    HWND window, flutter::BinaryMessenger* messenger) : window_(window) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "com.mashiro.sked/school_web_session",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "release") {
      if (operation_ && operation_->completed()) operation_.reset();
      result->Success();
      return;
    }
    if (call.method_name() != "clear") {
      result->NotImplemented();
      return;
    }
    if (operation_ && !operation_->completed()) {
      result->Error("school_web_session_busy", "A profile clear is in progress.");
      return;
    }
    operation_ = std::make_shared<ClearOperation>(std::move(result));
    operation_->Start(window_);
  });
}

SchoolWebSessionBridge::~SchoolWebSessionBridge() {
  channel_->SetMethodCallHandler(nullptr);
  if (operation_) operation_->Cancel();
  operation_.reset();
}
