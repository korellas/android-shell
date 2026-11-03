// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
#include "flutter_window.h"

#include <optional>
#include <shobjidl.h>
#include <shellapi.h>
#include "utils.h"

#include "flutter/generated_plugin_registrant.h"

namespace {
HRESULT ChooseFile(HWND owner, bool save, bool folder, const std::string& name,
                   std::string* selected) {
  IFileDialog* dialog = nullptr;
  HRESULT hr = CoCreateInstance(save ? CLSID_FileSaveDialog : CLSID_FileOpenDialog,
                               nullptr, CLSCTX_INPROC_SERVER,
                               IID_PPV_ARGS(&dialog));
  if (FAILED(hr)) return hr;
  FILEOPENDIALOGOPTIONS options = 0;
  hr = dialog->GetOptions(&options);
  if (SUCCEEDED(hr)) {
    hr = dialog->SetOptions(options | FOS_FORCEFILESYSTEM | FOS_PATHMUSTEXIST |
                           (folder ? FOS_PICKFOLDERS : (save ? FOS_OVERWRITEPROMPT : FOS_FILEMUSTEXIST)));
  }
  if (SUCCEEDED(hr) && !name.empty()) {
    const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         name.data(), static_cast<int>(name.size()),
                                         nullptr, 0);
    if (length == 0) {
      dialog->Release();
      return E_INVALIDARG;
    }
    std::wstring wide_name(length, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, name.data(),
                        static_cast<int>(name.size()), wide_name.data(), length);
    hr = dialog->SetFileName(wide_name.c_str());
  }
  if (SUCCEEDED(hr)) hr = dialog->Show(owner);
  if (SUCCEEDED(hr)) {
    IShellItem* item = nullptr;
    hr = dialog->GetResult(&item);
    if (SUCCEEDED(hr)) {
      PWSTR path = nullptr;
      hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
      if (SUCCEEDED(hr)) {
        *selected = Utf8FromUtf16(path);
        CoTaskMemFree(path);
      }
      item->Release();
    }
  }
  dialog->Release();
  return hr;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  files_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "dev.korellas.tilde/windows",
      &flutter::StandardMethodCodec::GetInstance());
  files_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setFullscreen") {
          bool enabled = false;
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto entry = args->find(flutter::EncodableValue("enabled"));
            if (entry != args->end()) {
              if (const auto* value = std::get_if<bool>(&entry->second)) enabled = *value;
            }
          }
          if (enabled != fullscreen_) {
            if (enabled) {
              MONITORINFO monitor = {};
              monitor.cbSize = sizeof(monitor);
              window_placement_.length = sizeof(window_placement_);
              if (!GetWindowPlacement(GetHandle(), &window_placement_) ||
                  !GetMonitorInfoW(MonitorFromWindow(GetHandle(), MONITOR_DEFAULTTONEAREST), &monitor)) {
                result->Error("fullscreen", "Could not read the window placement");
                return;
              }
              window_style_ = GetWindowLongPtrW(GetHandle(), GWL_STYLE);
              SetWindowLongPtrW(GetHandle(), GWL_STYLE, window_style_ & ~WS_OVERLAPPEDWINDOW);
              SetWindowPos(GetHandle(), HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
                           monitor.rcMonitor.right - monitor.rcMonitor.left,
                           monitor.rcMonitor.bottom - monitor.rcMonitor.top,
                           SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            } else {
              SetWindowLongPtrW(GetHandle(), GWL_STYLE, window_style_);
              SetWindowPlacement(GetHandle(), &window_placement_);
              SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
                           SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            }
            fullscreen_ = enabled;
          }
          result->Success();
          return;
        }
        if (call.method_name() == "openUrl" || call.method_name() == "openFolder") {
          std::string target;
          if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
            const auto entry = args->find(flutter::EncodableValue(call.method_name() == "openUrl" ? "url" : "path"));
            if (entry != args->end()) {
              if (const auto* value = std::get_if<std::string>(&entry->second)) target = *value;
            }
          }
          const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, target.data(), static_cast<int>(target.size()), nullptr, 0);
          if (length == 0) { result->Error("invalid_target", "No target was provided"); return; }
          std::wstring wide(length, L'\0');
          MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, target.data(), static_cast<int>(target.size()), wide.data(), length);
          SHELLEXECUTEINFOW info = {};
          info.cbSize = sizeof(info);
          info.fMask = SEE_MASK_ASYNCOK | SEE_MASK_FLAG_NO_UI;
          info.hwnd = GetHandle();
          info.lpVerb = L"open";
          info.lpFile = wide.c_str();
          info.nShow = SW_SHOWNORMAL;
          if (ShellExecuteExW(&info)) result->Success();
          else result->Error("open_target", "Windows could not open the target");
          return;
        }
        if (call.method_name() != "openFile" && call.method_name() != "saveFile" && call.method_name() != "chooseDirectory") {
          result->NotImplemented();
          return;
        }
        std::string name;
        if (const auto* args = std::get_if<flutter::EncodableMap>(call.arguments())) {
          const auto entry = args->find(flutter::EncodableValue("name"));
          if (entry != args->end()) {
            if (const auto* value = std::get_if<std::string>(&entry->second)) name = *value;
          }
        }
        std::string selected;
        const HRESULT hr = ChooseFile(GetHandle(), call.method_name() == "saveFile", call.method_name() == "chooseDirectory", name, &selected);
        if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) result->Success();
        else if (FAILED(hr)) result->Error("file_dialog", "Windows file selection failed");
        else result->Success(flutter::EncodableValue(selected));
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  files_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
