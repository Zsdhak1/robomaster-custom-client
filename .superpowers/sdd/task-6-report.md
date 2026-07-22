# v0.1.5 Phase 1, Task 6 报告

## 状态

已完成主仪表盘持久模块状态面板：任一已明确出现的模块离线时，侧栏以模块状态面板替换事件时间轴；全部恢复在线后自动切回。面板只读取 `moduleStatusMonitorProvider`，不读取通知开关，也不改变比赛事件记录路径。

## RED

先新增 `dashboard_side_panel_test.dart` 的三项 Widget 测试，覆盖：

- 离线切换、全部恢复后回到时间轴，以及离线优先排序。
- 模块离线通知关闭时，模块控制器的离线状态仍会显示状态面板。
- 面板显示期间事件仍由同一 `GameStateNotifier` 记录，恢复时间轴后可见。

本机首次 RED 命令在 30 秒内无回显，按任务约定停止等待；之后由协调 agent 补跑确认三项新测试全部通过。

## GREEN 与回归

实现 `DashboardSidePanel`、`ModuleStatusPanel` 和集中式文案，并将主仪表盘侧栏接入新组件。协调 agent 最终复验：

```text
flutter test test/dashboard_side_panel_test.dart test/dashboard_v012_test.dart --reporter expanded
9/9 passed
```

回归期间发现 `dashboard_v012_test.dart` 的旧期望为 `2`。根因是 `v0.1.5 Phase 1, Task 1` 已将默认 42mm 伤害从 `100` 校准为 `200`：默认英雄身份对 100 血敌方英雄的正确公式为 `ceil(100 / (200 × 0.6)) = 1`。因此仅将该过期断言同步为 `1`，未改动业务计算逻辑。

## 静态分析

```text
flutter analyze
No issues found!
```

## Material 3 影响

- 使用 `context.textTheme`、响应式间距和 8dp 行间距。
- 使用 `surfaceContainerLow`、`errorContainer` 与对应 on-color 表达层级和离线错误态。
- 不新增裸颜色、字号、阴影；面板 Card 明确为零阴影。
- 使用 300ms `AnimatedSwitcher` 完成侧栏切换。

## 自审

- 所有新增函数均小于 50 行，状态位于 Provider/Widget 边界的正确层级。
- 模块排序为离线优先、同状态按 `RobotModuleType.values` 顺序。
- 文案集中在 `module_status_strings.dart`，不展示协议原始状态值。
- 未改动事件记录、自定义图传或操作面板。
- 已保留 7 个 Flutter 平台生成文件为未暂存状态。

## 实现提交

`79c39ac feat: show persistent offline module panel`

## Concerns

无功能性 concerns。初始本机测试命令无回显，但协调 agent 已完成 9/9 复验。
