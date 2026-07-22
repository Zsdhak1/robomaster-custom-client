# v0.1.5 Phase 1, Task 4 实施报告

## 状态

已完成敌方普通免费、加速免费、付费和不确定复活分类，并为付费复活保留 `enemyBoughtRespawn` 严重事件类型。

## RED

- `flutter test test/notification_rule_engine_test.dart --plain-name "respawn"`
  - 结果：失败，`+1 -7`。
  - 失败原因符合预期：旧实现使用买活/免费二分类、角色标题和旧详情；容差内仍误判付费；缺少比赛时间时默认疑似买活；兼容包装返回加速时长。
- `flutter test test/notification_rule_engine_test.dart --plain-name "protocol robot number"`
  - 结果：失败，期望“敌方 7 号机器人复活”，实际为“敌方 5 号机器人复活”。

## GREEN

- `flutter test test/notification_rule_engine_test.dart --plain-name "respawn"`
  - 结果：8 项全部通过。
- `flutter test test/notification_rule_engine_test.dart test/notification_rule_profile_test.dart`
  - 结果：最终 23 项全部通过。
  - 官方规则档案断言确认普通复活为 `INFO`、付费复活为 `CRITICAL`。
- `flutter analyze`
  - 结果：`No issues found!`

## 修改

- 新增 `RespawnDurationBounds` 与 `expectedFreeRespawnBounds(...)`，同时计算普通和最快免费复活边界。
- 保留 `expectedFreeRespawnDuration(...)` 兼容包装，并固定返回普通免费复活时长。
- 战亡记录同时保存两条时间边界，并在每个 0 HP 快照持续记录基地血量是否降至阈值。
- 按“付费 → 加速免费 → 普通免费”顺序应用容差分类；缺失必要数据时返回方式不确定，绝不默认付费。
- 仅付费分支增加买活计数并返回 `enemyBoughtRespawn`；其余分支返回 `enemyRespawned`。
- 统一敌方复活标题和“用时/推断为”详情，区分基地低血量与补给区加速原因，并使用协议机器人号。
- 将复活规则测试拆分为独立场景，覆盖普通、两种加速原因、付费、容差、不确定、双边界兼容包装和 7 号哨兵标题。

## 自审

- 函数长度：新增及修改函数均不超过 50 行。
- 分层与状态：分类逻辑保留在规则引擎，模型位于协议无关逻辑模型文件，Widget 无业务逻辑变更。
- 空安全：未新增显式 `!`；缺少比赛时间、基地血量或战亡记录均安全降级。
- 常量与协议：阈值和速率均读取 `RespawnRuleConfig`；机器人标题读取 `notificationRobotBaseIds`。
- 错误与平台：无新增异步、网络、文件系统或平台特定代码。
- 回归：规则引擎与规则档案测试全部通过，静态分析零问题。

## 提交

- 主题：`feat: classify enemy respawn methods`
- 本报告随同该提交；最终哈希以 Git 元数据和交付回复为准。

## Concerns

- worktree 中已有 7 个 Flutter 平台生成文件改动，不属于 Task 4，保持未暂存且未提交。
- `test/notification_rule_profile_test.dart` 在基线提交中已包含 INFO/CRITICAL 官方默认值断言，因此本任务只运行并验证该文件，没有重复改写。

## 审查修复（2026-07-22）

### RED

- 精确命令：`flutter test test/notification_rule_engine_test.dart --plain-name "respawn"`
- 结果：失败，14 项复活测试中 12 项通过、2 项失败。
- 预期失败：
  - 倒置配置 `acceleratedProgressPerSecond < normalProgressPerSecond` 时，最快边界错误地变成 10 秒，而非安全规范化后的 2.5 秒。
  - `buybackDetectionEnabled = false` 时，普通免费复活错误地降级为“复活方式不确定”。
- 同轮新增的连续战亡回归已通过，确认当前基线中普通、加速和缺数据不确定分支未增加买活惩罚，明确付费分支会影响下一次所需进度。

### GREEN

- 精确命令：`flutter test test/notification_rule_engine_test.dart --plain-name "respawn"`
  - 结果：14 项全部通过。
- 精确命令：`flutter test test/notification_rule_engine_test.dart test/notification_rule_profile_test.dart`
  - 结果：28 项全部通过。
- 精确命令：`flutter analyze`
  - 结果：`No issues found!`

### 修复内容

- 使用普通速率与配置加速速率的较大值计算最快免费复活边界，保证 `fastest <= normal`，避免倒置自定义配置误报付费 CRITICAL 或污染买活计数。
- `buybackDetectionEnabled` 仅关闭付费识别：普通与加速免费复活继续分类，只有本应判为付费的分支降级为方式不确定。
- 新增连续两次战亡测试：普通、加速与缺数据不确定均不增加 `priorBuybackCount`；明确付费会增加惩罚，使下一次 12 秒复活仍落入加速免费区间。

### 新提交

- `b177e19` — `fix: harden enemy respawn classification`
