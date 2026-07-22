# v0.1.5 Phase 1, Task 5 报告

## 状态

DONE_WITH_CONCERNS

## RED

- 命令：`flutter test test/module_status_monitor_test.dart`
- 结果：失败（新建的测试导入 `module_status_monitor.dart` 时，该目标文件尚不存在，模块状态类型未定义），符合任务要求的 RED 原因。

## GREEN

- 命令：`flutter test test/module_status_monitor_test.dart test/notification_rule_engine_test.dart --reporter expanded`
- 结果：exit 0，30/30 通过。

## 静态分析

- 命令：`flutter analyze`
- 结果：exit 0，`No issues found!`

## 修改摘要

- 新增不可变模块状态读数、状态快照、在线/离线转换和 Riverpod 状态监控器。
- 将协议值 `0` 与 `2` 统一为离线；只合并明确出现的字段，首次明确离线会产生转换，首次在线不产生转换。
- 通知协议跟踪器改为接收 `ModuleStatusTransition`，离线键使用模块枚举名，恢复事件复用对应 `recoveryKey`。
- 规则引擎新增纯转发的 `moduleEvent`，并保留标记为弃用的旧列表适配入口，确保 Task 7 接入前现有运行时仍可编译和保持行为。
- 新增模块状态测试，并将规则引擎测试改为验证转换到通知的映射。

## 自审

- 所有新增或修改函数均少于 50 行。
- 状态快照在控制器更新时使用 `Map.unmodifiable`，读取和转换模型不依赖 Widget 或网络服务。
- Riverpod Provider 仅暴露模块状态，通知逻辑只消费转换；离线 `dedupKey` 和恢复 `recoveryKey` 一致。
- 没有空断言；未修改自定义图传、操作面板或 7 个已有平台生成文件。

## 提交

- 任务代码与测试：`042182e feat: track explicit module status transitions`
- 本报告：随后的文档提交。

## Concerns

- 无。

## 审查修复（Important）

- 移除了 `NotificationRuleEngine` 内的私有模块状态控制器和接收原始状态列表的兼容入口。该引擎现在仅将调用方提供的 `ModuleStatusTransition` 转发为通知事件。
- 现有 MQTT 通知运行时成为唯一临时状态源：它拥有 `ModuleStatusMonitorController`、在新比赛时重置，并只将产生的转换传给规则引擎。
- 将规则引擎测试拆分为独立的“调用方提供模块转换”用例，明确其只消费转换而不自行读取状态快照。
- 验证：`flutter analyze`，exit 0，`No issues found!`。
- `flutter test test/module_status_monitor_test.dart test/notification_rule_engine_test.dart --reporter expanded`：exit 0，31/31 通过。
- `flutter test test/notification_runtime_test.dart --reporter expanded`：exit 0，1/1 通过。

## 第二次审查修复（共享 Provider 实例）

### RED

- 命令：`flutter test test/module_status_monitor_test.dart test/notification_rule_engine_test.dart test/notification_runtime_test.dart --reporter expanded`
- 结果：exit 1；前 32 项通过，但新运行时测试错误地将完整 Proto3 快照产生的多个模块离线事件当作单一事件，`events.single` 抛出 `Bad state: Too many elements`。

### GREEN 与分析

- GREEN 命令：`flutter test test/module_status_monitor_test.dart test/notification_rule_engine_test.dart test/notification_runtime_test.dart --reporter expanded`
- 结果：exit 0，33/33 通过。
- 分析命令：`flutter analyze`
- 结果：exit 0，`No issues found!`。

### 修改摘要与自审

- 通知运行时由 `moduleStatusMonitorProvider.notifier` 注入唯一的模块状态控制器，不再自行创建实例。
- 运行时模块读数桥接函数只观察该注入控制器并将转换传给规则引擎；比赛重置作用于同一注入实例。
- 回归测试验证图传离线 key、共享注入控制器可观察的状态以及 reset 后状态清空；完整 Proto3 快照允许产生多个明确离线事件。
- 规则引擎和协议跟踪器均未保存模块状态；新增函数均少于 50 行，没有空断言。

### 提交

- 共享 Provider 注入修复：`d408e25 fix: share module status monitor with runtime`
- 本报告：随后的文档提交。

## 第三次审查修复（Proto3 字段存在性）

### 根因与 RED

- 根因：`RobotModuleStatus` 的 Proto3 标量字段在未携带时读取为默认值 `0`，旧 mapper 无条件读取全部 11 个字段，错误地将缺失字段转为离线。
- RED 命令：`flutter test test/notification_runtime_test.dart --reporter expanded`
- RED 断言：只构造 `RobotModuleStatus(videoTransmission: 0, armor: 1)` 时，仅图传产生离线事件；未携带的 `bigShooter` 不写入状态。旧实现会产生 11 个离线事件，因而失败。

### GREEN 与分析

- GREEN 命令：`flutter test test/module_status_monitor_test.dart test/notification_rule_engine_test.dart test/notification_runtime_test.dart --reporter expanded`
- 结果：exit 0，35/35 通过。
- 分析命令：`flutter analyze`
- 结果：exit 0，`No issues found!`。

### 修改摘要与自审

- mapper 对每个 `RobotModuleStatus` 字段使用对应的 `hasX()` presence API；显式值 `0` 仍保留并映射为离线，未携带字段不会猜测为离线。
- 测试验证 `videoTransmission: 0` 和 `armor: 1` 的 presence，未设置的 `bigShooter` 为 absent；验证后续缺失字段不会覆盖既有离线状态。
- `_moduleReading` 拆分为恰好 50 行以内的纯函数及小型 record 辅助函数；无空断言、无第二状态源、未修改平台生成文件。

### 提交

- Proto3 presence 修复：`4c316cf fix: respect module status field presence`
- 本报告：随后的文档提交。
