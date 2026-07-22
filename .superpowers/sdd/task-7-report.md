# v0.1.5 Phase 1, Task 7 报告

## 状态

已完成 MQTT 运行时的 Buff、模块字段和比赛级重置边界接入。运行时复用唯一的 `moduleStatusMonitorProvider` 控制器；没有新建第二套模块状态或映射状态。

## RED

先在 `notification_runtime_test.dart` 写入 Buff topic、presence-aware 模块映射、未知值忽略、信封时间 Buff 快照，以及比赛级重置边界测试；在 `notification_runtime_widget_test.dart` 写入共享 Provider 状态可见性测试。

- Task 5 已提前实现的部分：共享 `moduleStatusMonitorProvider` 注入、Protobuf 字段 presence 判断、已出现模块状态跨消息保留。这些测试覆盖其回归，而非伪造 RED。
- 初次 `flutter test` 使用环境的 batch wrapper 在 30 秒内无回显，未据此声称通过。
- 随后静态分析的实际 RED 为 `notification_providers.dart` 中 `CombatBuffSample` 未定义。根因是运行时文件缺少 `combat_buff_tracker.dart` 相对导入；已用单一导入修复，未改动其他逻辑。

## GREEN 与回归

- `notificationRequiredTopics` 现在必订阅 `topicBuff`。
- Buff 信封通过 `observeBuffFromProtocol` 使用 `envelope.timestamp` 写入引擎；处理血量时以同一信封时间调用 `combatBuffsAt(timestamp)`，不使用 `DateTime.now()` 查询 Buff。
- `moduleStatusReadingFromProtocol` 是可测试接口：只处理 `hasX()` 明确出现且值为 `0/1/2` 的字段；`0` 与 `2` 离线，`1` 在线，未知值忽略。
- MQTT 从 connected 离开、新小局、从 in-match 离开（包括结算等任意非 in-match 阶段）和选中身份变化都会统一清理 Buff、共享模块状态、击杀线/复活跟踪器、连接质量与部署状态。
- 共享模块 Provider 的协议更新在 Task 6 的模块状态面板中可见。

协调 agent 最终复验：

```text
flutter test test/notification_runtime_test.dart test/notification_runtime_widget_test.dart test/notification_rule_engine_test.dart test/module_status_monitor_test.dart --reporter expanded
47/47 passed

flutter analyze
No issues found!
```

## 格式化

使用 SDK 直接的 `dart.exe format` 格式化修改文件。格式化实际完成；进程最后尝试更新用户目录的 Dart telemetry 会话文件时因权限不足返回非零退出码。该 telemetry 权限问题不影响写入的格式化结果，最终 `flutter analyze` 已通过。

## 自审

- 所有新增函数小于 50 行；较长的协议字段枚举已拆分为两个小型 helper。
- 网络输入按 presence 与已知枚举值防御性过滤；未知模块值不会伪造离线状态。
- 状态留在规则引擎和共享 Provider 边界，Widget 不直接访问 MQTT。
- 协议主题和值均使用命名常量；无新增硬编码 UI 字符串。
- 未修改自定义图传或操作面板。
- 7 个 Flutter 平台生成文件保持未暂存、未提交。

## 实现提交

`f93774d feat: connect notification accuracy to live protocol`

## Concerns

初始 batch wrapper 无回显和本地 Dart telemetry 写入权限问题已记录，最终协调验证通过。

## 审查修复：Combat Buff 输入边界

审查发现实时 Buff 输入会接受任意机器人 ID、过大持续时间和异常等级，且过期项只在快照中跳过而未物理删除。已在 `0514479 fix: bound combat Buff tracker inputs` 修复：

- 仅接受机器人 ID `1..7` 与 `101..107`，两种 Buff 类型合计最多 28 个键。
- 仅接受等级 `-1000..1000`，保留现有 `150` 与负防御/易伤语义；超界整条忽略，不钳制。
- 仅接受剩余时间 `0..3600` 秒；`0` 仍删除，超界忽略。
- `snapshot` 先收集过期键、遍历结束后删除，避免迭代 Map 时修改；删除后旧时间戳样本不再受已过期记录的乱序保护。

本轮 RED 新增非法 ID、等级、持续时间、边界保留和过期删除可观察行为测试。初次本机 RED 命令仍在 30 秒无回显；协调 agent 最终复验：

```text
flutter test test/combat_buff_tracker_test.dart test/notification_runtime_test.dart test/notification_rule_engine_test.dart --reporter expanded
47/47 passed

flutter analyze
No issues found!
```

## 最终 Concerns

`notification_providers.dart` 目前约 513 行，存在 Minor 级可维护性 concern；按本次审查要求未进行大范围拆分，应在整个分支的后续审查中处理。
