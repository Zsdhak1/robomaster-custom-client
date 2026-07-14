# Learnings

## [LRN-20260713-001] correction

**Logged**: 2026-07-13T21:10:00+08:00
**Priority**: high
**Status**: resolved
**Area**: frontend

### Summary
桌面自定义标题栏覆盖层和嵌套导航动画必须通过真实 Windows 布局测试验证。

### Details
通知设置拆分测试只验证了导航结果，没有把 `SettingsScreen` 放入 `DesktopWindowFrame`，因此未发现顶部拖动区域覆盖返回按钮中心。嵌入式二级页也只返回透明主体，路由进入动画期间会透出上一层目录内容。

### Suggested Action
桌面顶部新增交互控件时，在 Windows 平台窗口框架下验证点击中心；嵌套 Navigator 推入的页面必须绘制覆盖整个路由区域的语义 `surface` 背景，并在动画中间帧验证尺寸。

### Metadata
- Source: user_feedback
- Related Files: lib/core/window/desktop_window_frame.dart, lib/features/settings/presentation/settings_screen.dart, lib/features/settings/presentation/notification_settings_subpages.dart
- Tags: windows, hit-test, navigator, transition, material3
- Pattern-Key: desktop.overlay_interactive_exclusion
- Recurrence-Count: 1
- First-Seen: 2026-07-13
- Last-Seen: 2026-07-13

### Resolution
- **Resolved**: 2026-07-13T21:25:00+08:00
- **Notes**: 详情返回栏在 Windows 下避开 36dp 拖动层；嵌入式通知二级页绘制完整 MD3 surface，并增加动画中间帧与点击中心回归测试。

---
