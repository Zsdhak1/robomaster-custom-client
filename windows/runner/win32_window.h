#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

// 高 DPI 感知 Win32 窗口的类抽象。
// 需要自定义渲染和输入处理的类可继承它。
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // 使用 |origin| 和 |size| 创建带 |title| 的 Win32 窗口。
  // 新窗口会创建在默认显示器上。窗口尺寸以物理像素传给 OS，
  // 因此该函数会根据默认显示器缩放输入宽高，以保持尺寸一致。
  // 在调用 |Show| 前窗口不可见。创建成功时返回 true。
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // 显示当前窗口；显示成功时返回 true。
  bool Show();

  // 释放与窗口关联的 OS 资源。
  void Destroy();

  // 将 |content| 插入窗口树。
  void SetChildContent(HWND content);

  // 返回底层窗口句柄，供客户端设置图标和其他窗口属性。
  // 如果窗口已销毁，则返回 nullptr。
  HWND GetHandle();

  // 为 true 时，关闭该窗口会退出应用。
  void SetQuitOnClose(bool quit_on_close);

  // 返回表示当前客户端区域边界的 RECT。
  RECT GetClientArea();

 protected:
  // 处理并路由与鼠标、尺寸变化和 DPI 相关的重要窗口消息。
  // 会把这些消息委托给继承类可处理的成员重载。
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // CreateAndShow 调用时触发，允许子类执行窗口相关设置。
  // 设置失败时子类应返回 false。
  virtual bool OnCreate();

  // Destroy 调用时触发。
  virtual void OnDestroy();

 private:
  friend class WindowClassRegistrar;

  // 消息泵调用的 OS 回调。
  // 处理 non-client 区域创建时传入的 WM_NCCREATE 消息，并启用自动 non-client DPI 缩放，
  // 使 non-client 区域能自动响应 DPI 变化。其他消息交给 MessageHandler 处理。
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // 获取 |window| 对应的类实例指针。
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // 更新窗口框架主题，使其匹配系统主题。
  static void UpdateTheme(HWND const window);

  bool quit_on_close_ = false;

  // 顶层窗口句柄。
  HWND window_handle_ = nullptr;

  // 托管内容的窗口句柄。
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
