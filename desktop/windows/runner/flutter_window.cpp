// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
#include "flutter_window.h"

#include <optional>
#include <algorithm>
#include <commctrl.h>
#include <dwmapi.h>
#include <windowsx.h>
#include <shobjidl.h>
#include <shellapi.h>
#include "utils.h"

#include "flutter/generated_plugin_registrant.h"

namespace {
bool ReadFrameRect(const flutter::EncodableMap& args, const char* key, RECT* rect) {
  const auto found = args.find(flutter::EncodableValue(key));
  if (found == args.end()) return false;
  const auto* values = std::get_if<flutter::EncodableList>(&found->second);
  if (!values || values->size() != 4) return false;
  LONG coordinates[4];
  for (size_t i = 0; i < 4; ++i) {
    const auto* value = std::get_if<int32_t>(&(*values)[i]);
    if (!value || *value < 0) return false;
    coordinates[i] = *value;
  }
  if (coordinates[2] < coordinates[0] || coordinates[3] < coordinates[1]) return false;
  *rect = {coordinates[0], coordinates[1], coordinates[2], coordinates[3]};
  return true;
}

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
        if (call.method_name() == "window.configure") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) { result->Error("window", "Expected frame configuration"); return; }
          const auto found = args->find(flutter::EncodableValue("enabled"));
          if (found == args->end() || !std::holds_alternative<bool>(found->second)) {
            result->Error("window", "Expected enabled flag"); return;
          }
          custom_frame_ = std::get<bool>(found->second);
          MARGINS margins = {0, 0, custom_frame_ ? 1 : 0, 0};
          DwmExtendFrameIntoClientArea(GetHandle(), &margins);
          SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
              SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
            {flutter::EncodableValue("maximized"), flutter::EncodableValue(IsZoomed(GetHandle()) != FALSE)},
            {flutter::EncodableValue("active"), flutter::EncodableValue(active_)},
            {flutter::EncodableValue("fullscreen"), flutter::EncodableValue(fullscreen_)},
          }));
          return;
        }
        if (call.method_name() == "window.hitTestRegions") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          RECT drag = {}, maximize = {};
          if (!args || !ReadFrameRect(*args, "drag", &drag) || !ReadFrameRect(*args, "maximize", &maximize)) {
            result->Error("window", "Expected physical client rectangles"); return;
          }
          drag_region_ = drag;
          maximize_region_ = maximize;
          result->Success();
          return;
        }
        if (call.method_name() == "window.minimize") {
          ShowWindow(GetHandle(), SW_MINIMIZE);
          result->Success(); return;
        }
        if (call.method_name() == "window.toggleMaximize") {
          ShowWindow(GetHandle(), IsZoomed(GetHandle()) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success(); return;
        }
        if (call.method_name() == "window.close") {
          PostMessageW(GetHandle(), WM_CLOSE, 0, 0);
          result->Success(); return;
        }
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
              fullscreen_ = true;
              window_style_ = GetWindowLongPtrW(GetHandle(), GWL_STYLE);
              SetWindowLongPtrW(GetHandle(), GWL_STYLE, window_style_ & ~WS_OVERLAPPEDWINDOW);
              SetWindowPos(GetHandle(), HWND_TOP, monitor.rcMonitor.left, monitor.rcMonitor.top,
                           monitor.rcMonitor.right - monitor.rcMonitor.left,
                           monitor.rcMonitor.bottom - monitor.rcMonitor.top,
                           SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            } else {
              fullscreen_ = false;
              SetWindowLongPtrW(GetHandle(), GWL_STYLE, window_style_);
              SetWindowPlacement(GetHandle(), &window_placement_);
              SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
                           SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            }
          }
          SendWindowState();
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
  if (!SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(),
      ViewWindowProc, 1, reinterpret_cast<DWORD_PTR>(this))) return false;

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
  if (flutter_controller_ && flutter_controller_->view()) {
    RemoveWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ViewWindowProc, 1);
  }
  files_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::FrameHitTest(LPARAM position) {
  if (!custom_frame_ || fullscreen_) return HTCLIENT;
  POINT point = {GET_X_LPARAM(position), GET_Y_LPARAM(position)};
  ScreenToClient(GetHandle(), &point);
  if (!IsZoomed(GetHandle())) {
    const UINT dpi = GetDpiForWindow(GetHandle());
    const int border = GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
        GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
    if (point.y < border) {
      RECT client = {}; GetClientRect(GetHandle(), &client);
      if (point.x < border) return HTTOPLEFT;
      if (point.x >= client.right - border) return HTTOPRIGHT;
      return HTTOP;
    }
  }
  if (PtInRect(&maximize_region_, point)) return HTMAXBUTTON;
  if (PtInRect(&drag_region_, point)) return HTCAPTION;
  return HTCLIENT;
}

LRESULT CALLBACK FlutterWindow::ViewWindowProc(HWND window, UINT message,
    WPARAM wparam, LPARAM lparam, UINT_PTR id, DWORD_PTR reference) {
  auto* self = reinterpret_cast<FlutterWindow*>(reference);
  if (message == WM_NCHITTEST && self->custom_frame_ &&
      self->FrameHitTest(lparam) != HTCLIENT) return HTTRANSPARENT;
  return DefSubclassProc(window, message, wparam, lparam);
}

void FlutterWindow::SendWindowState() {
  if (!files_channel_ || !custom_frame_) return;
  files_channel_->InvokeMethod("window.state", std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
    {flutter::EncodableValue("maximized"), flutter::EncodableValue(IsZoomed(GetHandle()) != FALSE)},
    {flutter::EncodableValue("active"), flutter::EncodableValue(active_)},
    {flutter::EncodableValue("fullscreen"), flutter::EncodableValue(fullscreen_)},
    {flutter::EncodableValue("maximizeHovered"), flutter::EncodableValue(maximize_hovered_)},
  }));
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (custom_frame_) {
    if (message == WM_NCCALCSIZE && wparam) {
      if (fullscreen_) return 0;
      auto* rects = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const LONG top = rects->rgrc[0].top;
      DefWindowProcW(hwnd, message, wparam, lparam);
      rects->rgrc[0].top = top + (IsZoomed(hwnd) ?
          GetSystemMetricsForDpi(SM_CYSIZEFRAME, GetDpiForWindow(hwnd)) +
          GetSystemMetricsForDpi(SM_CXPADDEDBORDER, GetDpiForWindow(hwnd)) : 0);
      return 0;
    }
    if (message == WM_NCHITTEST) {
      const LRESULT hit = FrameHitTest(lparam);
      if (hit != HTCLIENT) return hit;
      // The standard frame still owns its side and bottom resize borders.
      const LRESULT standard = DefWindowProcW(hwnd, message, wparam, lparam);
      if (standard == HTLEFT || standard == HTRIGHT || standard == HTBOTTOM ||
          standard == HTBOTTOMLEFT || standard == HTBOTTOMRIGHT) return standard;
      return HTCLIENT;
    }
    if (message == WM_GETMINMAXINFO) {
      DefWindowProcW(hwnd, message, wparam, lparam);
      auto* limits = reinterpret_cast<MINMAXINFO*>(lparam);
      limits->ptMinTrackSize.x = std::max<LONG>(limits->ptMinTrackSize.x, MulDiv(400, GetDpiForWindow(hwnd), 96));
      return 0;
    }
    if ((message == WM_NCLBUTTONDOWN || message == WM_NCLBUTTONUP) && wparam == HTMAXBUTTON) {
      const HWND content = flutter_controller_->view()->GetNativeWindow();
      POINT point = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(content, &point);
      SendMessageW(content, message == WM_NCLBUTTONDOWN ? WM_LBUTTONDOWN : WM_LBUTTONUP,
          message == WM_NCLBUTTONDOWN ? MK_LBUTTON : 0, MAKELPARAM(point.x, point.y));
      return 0;
    }
    if (message == WM_NCMOUSEMOVE && wparam == HTMAXBUTTON && !maximize_hovered_) {
      maximize_hovered_ = true;
      TRACKMOUSEEVENT tracking = {sizeof(TRACKMOUSEEVENT), TME_LEAVE | TME_NONCLIENT, hwnd, 0};
      TrackMouseEvent(&tracking);
      SendWindowState();
    }
    if (message == WM_NCMOUSELEAVE && maximize_hovered_) {
      maximize_hovered_ = false;
      SendWindowState();
    }
  }
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
    case WM_SIZE: {
      const LRESULT result = Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      SendWindowState();
      return result;
    }
    case WM_ACTIVATE:
      active_ = LOWORD(wparam) != WA_INACTIVE;
      SendWindowState();
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
