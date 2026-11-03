// Copyright 2026 Kenny Root
// SPDX-License-Identifier: Apache-2.0
#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  bool custom_frame_ = false;
  bool active_ = true;
  bool maximize_hovered_ = false;
  RECT drag_region_ = {}, maximize_region_ = {};
  LRESULT FrameHitTest(LPARAM position);
  void SendWindowState();
  static LRESULT CALLBACK ViewWindowProc(HWND window, UINT message,
      WPARAM wparam, LPARAM lparam, UINT_PTR id, DWORD_PTR reference);
  bool fullscreen_ = false;
  LONG_PTR window_style_ = 0;
  WINDOWPLACEMENT window_placement_ = {};

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> files_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
