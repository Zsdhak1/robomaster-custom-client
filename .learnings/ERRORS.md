# Errors

## [ERR-20260712-001] flutter-code-review-skill-path

**Logged**: 2026-07-12T00:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: config

### Summary
按技能显示名推导路径导致首次读取 Flutter 代码审查技能失败。

### Error
```
Get-Content : 找不到路径“C:\Users\hhh20\.codex\skills\flutter-code-review\SKILL.md”
```

### Context
- 尝试读取可用技能清单中的 `flutter-code-review`。
- 实际技能位置由别名 `r10/code_review/SKILL.md` 映射到项目 `.agents/skills/code_review/SKILL.md`。

### Suggested Fix
始终按技能清单提供的文件位置及 Skill roots 展开路径，不按技能名称猜测目录。

### Metadata
- Reproducible: yes
- Related Files: .agents/skills/code_review/SKILL.md

### Resolution
- **Resolved**: 2026-07-12T00:00:00+08:00
- **Notes**: 已改用技能清单中的实际路径并成功读取。

---

## [ERR-20260713-011] request-user-input-default-mode

**Logged**: 2026-07-13T21:30:00+08:00
**Priority**: low
**Status**: resolved
**Area**: config

### Summary
在 Default 协作模式误调用仅 Plan 模式可用的 `request_user_input`。

### Error
```
request_user_input is unavailable in Default mode
```

### Context
- 字体接入任务尝试确认全局范围与字重选择。
- 该问题不影响任务执行，可根据项目上下文采用保守默认值继续。

### Suggested Fix
Default 模式下优先做合理假设；只有无法安全推断时才直接向用户提出简短问题。

### Metadata
- Reproducible: yes
- Related Files: none

### Resolution
- **Resolved**: 2026-07-13T21:31:00+08:00
- **Notes**: 改为全局接入 Regular、Medium、Semibold、Bold 四个常用字重。

---

## [ERR-20260713-008] app-shell-pump-and-settle-timeout

**Logged**: 2026-07-13T00:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
AppShell 组件测试使用 pumpAndSettle 时，被现有持续动画或周期状态拖住并超时。

### Error
```
pumpAndSettle timed out
```

### Context
- 为等待非默认初始导航切换，把共享 `_pumpShell` 从固定 pump 改为 pumpAndSettle。
- 该改动导致所有 AppShell 组件测试超时，而非单个通知功能失败。

### Suggested Fix
对包含持续动画、定时器或流的应用外壳使用确定次数或确定时长的 pump；只在确认动画会静止的局部组件使用 pumpAndSettle。

### Metadata
- Reproducible: yes
- Related Files: test/notification_runtime_widget_test.dart

### Resolution
- **Resolved**: 2026-07-13T00:00:00+08:00
- **Notes**: 恢复两次固定 pump，并将通知测试拆为设置请求、控制器策略与既有全局覆盖层三项确定性测试。

---

## [ERR-20260713-007] app-shell-initial-provider-mutation

**Logged**: 2026-07-13T00:00:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
AppShell 使用非默认 initial 页面时，在 initState 同步修改 Riverpod Provider 会触发构建期写入断言。

### Error
```
Tried to modify a provider while the widget tree was building.
```

### Context
- 默认 dashboard 与 Provider 初始值相同，因此旧测试未暴露。
- 设置页通知测试的全局集成用例使用 `AppShell(initial: AppDestination.settings)` 后稳定复现。

### Suggested Fix
Widget 生命周期初始化需要写 Riverpod 状态时，使用首帧回调延后修改，并在回调中检查 mounted。

### Metadata
- Reproducible: yes
- Related Files: lib/core/navigation/app_shell.dart, test/notification_runtime_widget_test.dart
- Recurrence-Count: 2
- Last-Seen: 2026-07-13

### Resolution
- **Resolved**: 2026-07-13T00:00:00+08:00
- **Notes**: 改用 WidgetsBinding.addPostFrameCallback，并补充非默认初始页面集成测试。

---

## [ERR-20260713-006] notification-test-app-shell-imports

**Logged**: 2026-07-13T00:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
新增设置页通知测试组合层接线后，AppShell 首次静态分析缺少设置档案与事件配置导入。

### Error
```
Undefined name 'activeNotificationProfileProvider'.
The name 'NotificationEventSetting' isn't a class.
```

### Context
- AppShell 新增通知测试调度回调。
- 首次补丁只导入测试请求 Provider，遗漏其运行时所需的档案 Provider 和事件设置类型。

### Suggested Fix
组合层新增跨模块回调时，在首次分析前核对回调签名中所有显式类型和 Provider 的来源，并保持导入分组排序。

### Metadata
- Reproducible: yes
- Related Files: lib/core/navigation/app_shell.dart, test/notification_runtime_widget_test.dart
- Recurrence-Count: 2
- Last-Seen: 2026-07-13

### Resolution
- **Resolved**: 2026-07-13T00:00:00+08:00
- **Notes**: 补充 notification_preferences.dart 与 notification_profile_provider.dart 导入。

---

## [ERR-20260713-005] powershell-variable-colon-interpolation

**Logged**: 2026-07-13T00:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: config

### Summary
PowerShell 双引号字符串中的变量后紧跟冒号时被解析为无效变量引用。

### Error
```
InvalidVariableReferenceWithDrive
```

### Context
- 代码长度自审脚本输出 `$file:$line` 时触发。
- PowerShell 会把冒号视为变量作用域或驱动器语法的一部分。

### Suggested Fix
变量后紧跟冒号时使用 `${file}:$line` 显式界定变量名。

### Metadata
- Reproducible: yes
- Related Files: none

### Resolution
- **Resolved**: 2026-07-13T00:00:00+08:00
- **Notes**: 改用 `${file}` 后脚本正常完成。

---

## [ERR-20260713-004] flutter-test-batch-wrapper-loop

**Logged**: 2026-07-13T00:05:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
当前 PowerShell 环境直接调用 `flutter test` 时产生无输出的高 CPU `cmd.exe` 循环。

### Error
```
flutter test remained silent while cmd.exe consumed CPU.
Direct flutter_tools invocation initially failed to update SDK cache/lockfile in the sandbox.
```

### Context
- `flutter analyze` 通过批处理入口可正常执行，但 `flutter test` 在同一入口异常循环。
- 直接使用 SDK Dart 启动 `flutter_tools.dart test` 可绕过批处理循环。
- Flutter 测试需要写 SDK cache 锁文件，因此在受限沙箱中需使用已审批的提权命令。

### Suggested Fix
Windows 受限环境运行测试时使用 Flutter SDK Dart 直接启动 `flutter_tools.dart test`，并为 SDK cache 锁文件申请最小范围权限。

### Metadata
- Reproducible: yes
- Related Files: test/
- Recurrence-Count: 2
- Last-Seen: 2026-07-13

### Resolution
- **Resolved**: 2026-07-13T00:07:00+08:00
- **Notes**: 新增 6 项测试和全量 151 项测试均通过。

---

## [ERR-20260712-003] dart-format-telemetry-permission

**Logged**: 2026-07-12T23:30:00+08:00
**Priority**: low
**Status**: resolved
**Area**: config

### Summary
`dart format` 已完成源码格式化，但 Dart 遥测会话文件写入用户目录失败并返回非零退出码。

### Error
```
FileSystemException: Failed to set file modification time,
path = 'C:\Users\hhh20\AppData\Roaming\.dart-tool\dart-flutter-telemetry-session.json'
```

### Context
- 首次通过 PATH 中的 `dart format` 启动时进程长时间无输出。
- 改用 Flutter SDK 内显式 `dart.exe format` 后 15 个文件均成功格式化。
- 命令结束阶段因沙箱禁止写用户遥测目录而返回退出码 1。

### Suggested Fix
在受限环境中使用 Flutter SDK 内显式 Dart，并根据格式化输出确认源码结果；后续如可配置，关闭 Dart analytics。

### Metadata
- Reproducible: yes
- Related Files: lib/features/settings/
- Recurrence-Count: 4
- Last-Seen: 2026-07-13

### Resolution
- **Resolved**: 2026-07-12T23:31:00+08:00
- **Notes**: 格式化已完成，随后 `flutter analyze` 验证零问题。

---

## [ERR-20260712-002] pdf-text-output-encoding

**Logged**: 2026-07-12T00:00:00+08:00
**Priority**: low
**Status**: resolved
**Area**: docs

### Summary
Windows 默认 GBK 控制台编码导致中文 PDF 文本抽取输出中断。

### Error
```
UnicodeEncodeError: 'gbk' codec can't encode character
```

### Context
- 使用 bundled Python + pypdf 检索通信协议和比赛规则手册。
- PDF 文本可正常提取，但输出到 PowerShell 控制台时编码失败。

### Suggested Fix
在 PDF 抽取脚本开头调用 `sys.stdout.reconfigure(encoding='utf-8', errors='replace')`。

### Metadata
- Reproducible: yes
- Related Files: RoboMaster 2026 机甲大师高校系列赛通信协议 V1.3.1（20260519）_decrypted.pdf

### Resolution
- **Resolved**: 2026-07-12T00:00:00+08:00
- **Notes**: 强制 UTF-8 后成功抽取协议页和规则页。

---
## [ERR-20260713-009] settings-detail-navigator-page-callback

**Logged**: 2026-07-13T20:45:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
宽屏设置详情区使用 `Navigator.pages` 时缺少当前 Flutter 要求的页面移除回调。

### Error
```
Either onDidRemovePage or onPopPage must be provided to use the Navigator.pages API but not both.
```

### Context
- 通知设置拆分为二级页面后新增宽屏嵌套导航测试。
- `_DetailPanel` 的 `Navigator` 只传入 `pages`，打开设置详情区即触发断言。

### Suggested Fix
使用 `Navigator.pages` 时提供 `onDidRemovePage`，并通过组件测试覆盖详情区 push/pop。

### Metadata
- Reproducible: yes
- Related Files: lib/features/settings/presentation/settings_screen.dart, test/notification_rules_settings_screen_test.dart

### Resolution
- **Resolved**: 2026-07-13T20:46:00+08:00
- **Notes**: 为内嵌 Navigator 增加 `onDidRemovePage`，继续运行宽屏二级导航测试。

---
## [ERR-20260713-010] settings-import-order

**Logged**: 2026-07-13T21:15:00+08:00
**Priority**: low
**Status**: resolved
**Area**: frontend

### Summary
设置页新增桌面窗口依赖后，相对导入未按字母顺序排列。

### Error
```
Sort directive sections alphabetically. Try sorting the directives.
```

### Context
- 为详情返回栏增加 Windows 标题栏安全偏移时新增两个 core 导入。
- `flutter analyze` 的 `directives_ordering` 规则发现顺序问题。

### Suggested Fix
新增导入后立即按 dart、package、relative 分组并在组内按字母顺序排列。

### Metadata
- Reproducible: yes
- Related Files: lib/features/settings/presentation/settings_screen.dart

### Resolution
- **Resolved**: 2026-07-13T21:16:00+08:00
- **Notes**: 已调整 `design_constants.dart` 与 `responsive_ext.dart` 的导入顺序。

---
