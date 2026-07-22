# v0.1.5 最终整分支审查修复报告

## 状态

DONE_WITH_CONCERNS

最终审查及合并门禁复审发现的 Critical/Important 问题均已闭环。当前独立验证为聚焦回归 98/98、`flutter analyze` 无问题、全量回归 269/269。保留的 concern 仅为 `notification_providers.dart` 的 Minor 可维护性问题；不在发布前为文件长度做高风险重构。

## 问题闭环

### 1. 移除指挥性集火功能（Critical）

- 删除敌方最低血量比例选择算法、建议栏调用、`_buildSuggestionBar`、`Icons.whatshot` 和“集火目标”UI。
- `enemyFocus` 保留为中性的“敌方详情 + 己方趋势”布局，说明改为快速查看敌方各机器人状态。
- 保留双方总血量、逐机器人血量、低血量状态与弹丸估算。
- 新增 Widget 与源码定点断言，生产代码和现行设置文案不再包含“集火”。

RED：`test/robot_status_list_test.dart` 初次运行 0/2，通过失败证据分别为发现 1 个“集火目标”Widget，以及生产源码仍包含“集火”。

GREEN：同文件 2/2 通过。

### 2. Buff Protobuf 必要字段 presence（Important）

- `observeBuffFromProtocol` 仅在 `robotId`、`buffType`、`buffLevel`、`buffLeftTime` 四个 `hasX()` 均为 true 时写入 tracker，并返回是否接收。
- 缺任意字段整条忽略；显式 `buffLevel=0` 仍是合法值，显式 `buffLeftTime=0` 仍可删除已有 Buff。

RED：`test/notification_runtime_test.dart` 初次运行 14/15，缺 `buffLevel` 的默认 0 覆盖了已有 150，输出 `Expected: <150>, Actual: <0>`。

GREEN：加入全部 presence、显式 0 与完整样本覆盖后，该文件最终 18/18 通过。

### 3. 倒计时/基地血量 presence 与复活原因三态（Important）

- 小型纯 helper 仅在 `hasStageCountdownSec()` / `hasEnemyBaseHealth()` 为 true 时返回协议值，缺失返回 null，显式 0 保留。
- 战亡期间基地证据改为 `low` / `notLow` / `unknown`：low 一旦出现即保持；缺失不覆盖已有证据；unknown 可被明确高血量升级为 notLow。
- 加速免费复活详情分别为“基地低血量加速免费复活”“补给区加速免费复活”“加速原因不确定”。
- 缺倒计时不会计算免费复活边界，不会误判付费或增加买活惩罚。

RED：`test/notification_rule_engine_test.dart` 初次新增回归运行 28/31；unknown 被错误写成“补给区加速免费复活”，另有两项不确定抑制测试失败。

GREEN：同文件最终 31/31 通过；presence helper 由 `notification_runtime_test.dart` 覆盖。

### 4. uncertainBehavior 设置生效（Important）

- 真正 uncertain（缺必要数据，或 paid 但关闭 buyback detection）在 `suppress` 时不产生事件，在 `suspected` 时保留统一标题与“复活方式不确定”。
- 普通免费和加速免费不受该设置或 buyback detection 开关影响。
- 只有确定 paid 才增加惩罚，原有后续死亡惩罚回归继续通过。

RED：`suppress` 两项测试均收到 1 个不应产生的 `RuleNotificationEvent`。

GREEN：suppress、suspected、普通免费、加速免费与惩罚回归全部包含在规则引擎 31/31 中。

### 5. 恢复事件与通知会话生命周期（Important）

- `showConfigured` 在 setting lookup、总开关、事件开关、暂停和冷却之前，无条件按 `recoveryKey` 关闭旧持续告警。
- 新增 `resetRuntimeState()`：取消 dismiss timers、清 visible、清 cooldown 基线并保留 history。
- 统一比赛级 reset 清规则引擎、通知运行时、连接质量、UDP 窗口与部署状态；共享模块 baseline 仅在 MQTT 会话结束时额外清理。

RED：disabled、paused、cooldown 三种恢复场景均残留 1 个旧告警；新增 reset 测试初次编译明确报 `resetRuntimeState isn't defined`。

GREEN：`test/dashboard_notification_controller_test.dart` 7/7 通过，覆盖恢复顺序、历史保留和 reset 后首条离线事件不受旧 cooldown 抑制。

### 6. MQTT 连接会话 fence 与旧比赛状态清理（Important）

- MQTT 接收边界为每条消息保存原始 `receivedAt` 和 connection generation，缓存重放不会重新生成接收时刻或代次。
- `ProtobufEnvelope` 沿用接收边界提供的时间和 generation；通知运行时以 generation 作为会话边界，不会因自身创建较晚而拒绝当前 generation 的合法缓存。
- `MqttService` 的底层 updates 监听绑定创建时 generation，旧客户端迟到回调在进入缓存前即被拒绝。
- 从 connected 离开时清 `_gameStatus`、连接/消息时间基线并统一 reset；重连前后的血量不会按旧 in-match 状态处理。

RED：合并门禁复审证明原实现只比较 parse 时生成的时间，上一连接的缓存会在重放时伪装为新消息；新增 generation API 和缓存重放测试首先以缺少模型/参数的编译错误失败。

GREEN：`test/notification_runtime_widget_test.dart` 6/6 通过，覆盖旧 generation 的缓存比赛状态无法恢复、当前 generation 协议事件仍可处理，以及运行时创建前收到的当前 generation 缓存比赛状态仍然有效；纯 fence 测试覆盖 disconnected、缺 generation、generation 不匹配和当前会话接受。

### 8. 首次离线与设置说明语义（Important）

- 首次明确离线写为“模块明确上报离线状态”，只有已经观测到在线后再离线才写“由在线变为离线”。
- 设置页准确说明普通免费、加速免费、方式不确定、付费复活、两种免费复活进度速度、敌方基地阈值，以及首次明确离线的事件覆盖范围。

RED：模块转换和设置说明定点回归分别得到旧文案，2 项断言失败。

GREEN：模块规则与设置页共 39 项测试通过，并包含三项设置说明精确断言。

### 7. UDP 采样窗口 reset（Minor）

- `_UdpWindowSampler` 提取为文件内职责明确且可测试的 `UdpWindowSampler`，新增 `reset()` 清空 samples。
- 统一 `_resetMatchState()` 调用 reset，确保新局第一个样本返回 null，不沿用旧窗口。

RED：API 测试初次编译明确报 `UdpWindowSampler` 未定义。

GREEN：`notification_runtime_test.dart` 的窗口回归证明 reset 后首样本返回 null；最终该文件 18/18 通过。

### 9. 生产启动顺序与独立缓存重放（Critical）

- 提取 `mqttEnvelopeStreamFactoryProvider`，共享 `mqttMessageProvider` 与通知运行时分别创建 Protobuf 解析订阅；两个订阅都会从 `MqttService.messageStream` 独立、完整重放缓存。
- 通知运行时保存 `StreamSubscription<ProtobufEnvelope>`，在 `dispose()` 中取消，避免 Provider 释放后继续处理消息。
- 解析继续沿用 MQTT 接收边界记录的 `receivedAt` 和 connection generation；旧 generation 拒绝语义不变，自定义图传仍直接订阅原始 MQTT 字节流，行为未修改。

RED：先激活并消费共享 `mqttMessageProvider` 缓存后再创建通知运行时，`notification_runtime_widget_test.dart` 为 4/6；当前 generation 的 GameStatus + 血量序列未产生斩杀线通知，旧 generation 被拒绝后的当前 generation 事件也未被处理。

GREEN：通知运行时改用独立解析订阅后，该文件 6/6；当前 generation 缓存可驱动通知，旧 generation 仍被拒绝且当前事件正常处理。

### 10. 比赛级与 MQTT 会话级模块状态（Important）

- 比赛级 reset（新小局、离开比赛阶段及身份变化）保留 `moduleStatusMonitor`，因此离线面板可跨比赛边界持续显示，相同离线读数不会重复首次离线提醒。
- MQTT 从 connected 离开时先执行全部比赛级清理，再额外清空模块状态；重连后的首个明确快照重新建立连接级 baseline。

RED：`notification_runtime_test.dart` 为 17/18，比赛 reset 后模块状态实际为 null；补充真实断线路径后 `notification_runtime_widget_test.dart` 为 5/6，MQTT 断开仍残留离线模块。

GREEN：比赛 reset 保留离线状态与去重 baseline，运行时单元测试 18/18；MQTT 断开专属清理模块状态，Widget 测试 6/6。

## RED / GREEN 命令

普通 batch wrapper 首次等待 30 秒无回显且检查不到 `flutter` / `dart` 进程；随后使用同一 Flutter SDK 的直接入口取得实际证据：

```text
D:\11AndroidLearnings\Env\flutter\bin\cache\dart-sdk\bin\dart.exe D:\11AndroidLearnings\Env\flutter\bin\cache\flutter_tools.snapshot test <test-file> --reporter expanded
```

逐文件实际运行：

- `test/robot_status_list_test.dart`：RED 0/2 → GREEN 2/2。
- `test/notification_runtime_test.dart`：RED 14/15；新增 helper API 时取得预期未定义编译 RED → GREEN 18/18。
- `test/notification_rule_engine_test.dart`：RED 28/31 → GREEN 31/31。
- `test/dashboard_notification_controller_test.dart`：RED 3 项恢复顺序失败；reset API 取得预期未定义编译 RED → GREEN 7/7。
- `test/notification_runtime_widget_test.dart`：旧比赛状态 RED、启动 tracker RED → GREEN 4/4。
- 本轮启动顺序：`test/notification_runtime_widget_test.dart` RED 4/6 → GREEN 6/6。
- 本轮比赛级模块生命周期：`test/notification_runtime_test.dart` RED 17/18 → GREEN 18/18。
- 本轮 MQTT 会话模块生命周期：`test/notification_runtime_widget_test.dart` RED 5/6 → GREEN 6/6。

## 最终独立验证

本轮在全部实现、机械格式化和文档同步后实际运行 Flutter SDK 直入口：

```text
D:\11AndroidLearnings\Env\flutter\bin\cache\dart-sdk\bin\dart.exe D:\11AndroidLearnings\Env\flutter\bin\cache\flutter_tools.snapshot test --no-pub --reporter expanded test/dashboard_notification_controller_test.dart test/combat_buff_tracker_test.dart test/module_status_monitor_test.dart test/notification_runtime_test.dart test/notification_runtime_widget_test.dart test/notification_rule_engine_test.dart test/robot_status_list_test.dart test/notification_rules_settings_screen_test.dart test/dashboard_side_panel_test.dart test/custom_byte_block_source_test.dart
D:\11AndroidLearnings\Env\flutter\bin\cache\dart-sdk\bin\dart.exe D:\11AndroidLearnings\Env\flutter\bin\cache\flutter_tools.snapshot analyze --no-pub
D:\11AndroidLearnings\Env\flutter\bin\cache\dart-sdk\bin\dart.exe D:\11AndroidLearnings\Env\flutter\bin\cache\flutter_tools.snapshot test --no-pub --reporter expanded
```

- 聚焦回归：exit 0，98/98，`All tests passed!`。
- 静态分析：exit 0，`No issues found!`。
- 全量回归：exit 0，269/269，`All tests passed!`。

## 自审

- [x] 新增/修改函数均不超过 50 行；未为 `notification_providers.dart` 总文件长度做重构。
- [x] Widget 不处理 MQTT、RawSocket 或协议解析；新增会话逻辑仍位于运行时/data 接入层。
- [x] Protobuf 标量 presence、显式 0、未知值和 null 均有防御性处理。
- [x] 无新增显式 null 断言 `!`；导入按 dart/package/相对路径分组并通过 analyze。
- [x] 恢复事件、通知 timers/cooldown/history、MQTT generation 和 UDP 采样均有明确生命周期。
- [x] 自定义图传和操作面板未修改。
- [x] 7 个平台生成文件与 `docs/presentations/` 不暂存、不提交。
- [x] `pubspec.yaml`、v0.1.5 进度块和 Changelog 版本一致。

## 提交

- 本修复基线前 HEAD：`1f8eb42`。
- 本轮最终门禁修复基线 HEAD：`a71ae6a`。
- 本报告、实现、测试和 `feature_spec.md` 收口位于同一最终提交；提交哈希由交付消息记录，避免在提交内容中自引用哈希。

## 剩余 Minor

1. `lib/features/dashboard/logic/notification_providers.dart` 仍有 Minor 级文件职责与长度可维护性 concern。本轮未做高风险拆分；当前 98 项聚焦回归、269 项全量回归和零问题静态分析均未发现功能阻塞，留待后续独立重构任务。
