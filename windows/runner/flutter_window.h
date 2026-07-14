#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// 托管 Flutter 视图的空窗口。
class FlutterWindow : public Win32Window {
 public:
  // 创建托管 Flutter 视图并运行 |project| 的 FlutterWindow。
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window 钩子：
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void RegisterWindowChannel();

  // 要运行的 project。
  flutter::DartProject project_;

  // 该窗口托管的 Flutter 实例。
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
