# v0.1.5 Battlefield Notification Accuracy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 校正规则驱动的敌方复活与斩杀线通知，并在本机模块离线期间用持久模块状态面板临时替换主仪表盘事件时间轴。

**Architecture:** 保留现有 `NotificationRuleEngine`、专项跟踪器、通知控制器和设置系统。新增纯 Dart Buff 跟踪器与存在性明确的模块状态控制器；MQTT 运行时只负责把 Protobuf 转为这些纯输入，主仪表盘只根据模块控制器状态选择事件时间轴或模块面板。

**Tech Stack:** Flutter 3.x、Dart 3.x、flutter_riverpod、Protobuf、flutter_test。

## Global Constraints

- 当前应用定位是操作手信息副屏，只陈述战场事实、规则推断和本机异常，不承担指挥、语音或任务分配。
- 所有推断必须明确写成推断；禁止“集火”等指挥性文案。
- 攻击 Buff 只修正弹丸伤害；防御/易伤同时修正弹丸与撞击伤害；最终伤害只四舍五入一次。
- 撞击原始伤害固定为 2；17mm 和 42mm 默认原始伤害分别校正为 20 和 200。
- `RobotModuleStatus` 未携带的可选字段不得当作离线；状态 `0/2` 均视为离线。
- 模块状态面板独立于通知开关；隐藏时间轴时比赛事件仍正常记录。
- 不修改 UDP 3334、`CustomByteBlock`、视频重组、解码桥或操作面板。
- UI 字符串放入常量文件；Widget 不直接解析 Protobuf；单函数不超过 50 行。
- 执行 Task 6 前读取并遵循项目的 `material-3` skill，复用现有主题和响应式令牌。
- 每次文件写入后运行 `flutter analyze`；每个任务先写失败测试，再写最小实现。
- 临时目录 `docs/presentations/` 不暂存、不提交。

---

## File Structure

- `lib/features/dashboard/logic/combat_buff_tracker.dart`：纯 Dart Buff 样本、有效快照、乱序保护和过期查询。
- `lib/features/dashboard/logic/module_status_monitor.dart`：模块枚举、存在性明确的协议读数、状态转换和 Riverpod 控制器。
- `lib/features/dashboard/logic/kill_line_notification_tracker.dart`：按登录身份和有效 Buff 计算斩杀线。
- `lib/features/dashboard/logic/notification_rule_engine.dart`：组合 Buff、复活和斩杀线跟踪器，管理比赛级重置。
- `lib/features/dashboard/logic/notification_protocol_tracker.dart`：把模块状态转换映射为离线/恢复通知，不再保存第二份模块状态。
- `lib/features/dashboard/logic/notification_rule_models.dart`：血量快照携带有效 Buff 快照，提供敌方编号文案函数。
- `lib/features/dashboard/logic/notification_providers.dart`：将 `Buff`、`RobotModuleStatus` 和连接状态接入规则引擎及模块控制器。
- `lib/features/dashboard/presentation/widgets/module_status_panel.dart`：模块持久状态列表。
- `lib/features/dashboard/presentation/widgets/dashboard_side_panel.dart`：在时间轴和模块状态面板间切换。
- `lib/features/dashboard/presentation/module_status_strings.dart`：模块面板标题和状态文案。
- `test/combat_buff_tracker_test.dart`：Buff 有效期、乱序、易伤和重置测试。
- `test/module_status_monitor_test.dart`：首次离线、字段存在性、转换、恢复及重连测试。
- `test/dashboard_side_panel_test.dart`：持久模块面板自动切换和事件保留测试。
- `test/notification_rule_engine_test.dart`：复活分类、武器映射、伤害修正和工程撞击阈值测试。
- `test/notification_rule_profile_test.dart`：官方规则版本、默认伤害与默认通知严重级别测试。

---

### Task 1: 正式登记 v0.1.5 与规则默认值

**Files:**
- Modify: `pubspec.yaml`
- Modify: `feature_spec.md`
- Modify: `lib/features/settings/domain/kill_estimate_config.dart`
- Modify: `lib/features/settings/domain/notification_rule_profile.dart`
- Modify: `test/notification_rule_profile_test.dart`

**Interfaces:**
- Produces: `pubspec.yaml` 版本 `0.1.5`、官方规则版本 `2.0.0`、17mm/42mm 默认伤害 `20/200`、敌方普通复活默认 `INFO`、敌方付费复活默认 `CRITICAL`。

- [ ] **Step 1: 写失败测试，锁定规则版本、伤害和严重级别**

在 `test/notification_rule_profile_test.dart` 增加：

```dart
test('official profile matches 2026 V2.0.0 notification defaults', () {
  final profile = NotificationRuleProfile.official();
  expect(profile.ruleVersion, '2.0.0');
  expect(
    profile.eventSettings[NotificationEventType.enemyRespawned]?.severity,
    NotificationSeverity.info,
  );
  expect(
    profile.eventSettings[NotificationEventType.enemyBoughtRespawn]?.severity,
    NotificationSeverity.critical,
  );
  expect(defaultSmallProjectileDamage, 20);
  expect(defaultLargeProjectileDamage, 200);
});
```

- [ ] **Step 2: 运行测试并确认因旧默认值失败**

Run: `flutter test test/notification_rule_profile_test.dart`

Expected: FAIL，实际规则版本为 `1.5.0`、普通复活为 `critical` 或默认伤害为 `10/100`。

- [ ] **Step 3: 更新正式版本与规则默认值**

将 `pubspec.yaml` 改为：

```yaml
version: 0.1.5
```

将 `kill_estimate_config.dart` 的默认值改为：

```dart
const double defaultSmallProjectileDamage = 20;
const double defaultLargeProjectileDamage = 200;
```

将 `notification_rule_profile.dart` 的规则版本和默认事件映射改为：

```dart
const String officialRuleVersion = '2.0.0';

NotificationEventType.enemyBoughtRespawn ||
NotificationEventType.enemyKillLine ||
NotificationEventType.enemyRequestedLevelFour ||
NotificationEventType.moduleDisconnected => critical,
_ => info,
```

在 `feature_spec.md` 顶部接手摘要和开发进度表登记 `v0.1.5 Phase 1–4`，状态标记为开发中；每个 Task 使用 `v0.1.5 Phase N, Task M` 前缀。附录 E 顶部新增 2026-07-22 的 `0.1.5` 开发记录，不标记未完成事项为已实现。

- [ ] **Step 4: 验证默认值与静态分析**

Run: `flutter test test/notification_rule_profile_test.dart`

Expected: PASS。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 5: 提交版本登记与默认值**

```bash
git add pubspec.yaml feature_spec.md lib/features/settings/domain/kill_estimate_config.dart lib/features/settings/domain/notification_rule_profile.dart test/notification_rule_profile_test.dart
git commit -m "chore: start v0.1.5 notification accuracy"
```

---

### Task 2: Buff 有效状态跟踪器

**Files:**
- Create: `lib/features/dashboard/logic/combat_buff_tracker.dart`
- Create: `test/combat_buff_tracker_test.dart`

**Interfaces:**
- Produces: `CombatBuffSample`、`CombatBuffLevels`、`CombatBuffTracker.observe(CombatBuffSample)`、`CombatBuffTracker.snapshot(DateTime)`、`CombatBuffTracker.reset()`。
- Consumers: Task 3 的斩杀线计算和 Task 7 的 MQTT `Buff` 接入。

- [ ] **Step 1: 写失败测试覆盖过期、乱序、负防御和重置**

创建 `test/combat_buff_tracker_test.dart`，核心断言为：

```dart
test('keeps newest combat buffs until protocol remaining time expires', () {
  final tracker = CombatBuffTracker();
  final now = DateTime(2026, 7, 22, 12);
  tracker
    ..observe(CombatBuffSample(
      robotId: 1,
      buffType: combatAttackBuffType,
      level: 150,
      leftSeconds: 5,
      receivedAt: now,
    ))
    ..observe(CombatBuffSample(
      robotId: 101,
      buffType: combatDefenseBuffType,
      level: -25,
      leftSeconds: 5,
      receivedAt: now,
    ));

  final active = tracker.snapshot(now.add(const Duration(seconds: 4)));
  expect(active.attackLevelFor(1), 150);
  expect(active.defenseLevelFor(101), -25);
  expect(
    tracker.snapshot(now.add(const Duration(seconds: 6))).attackLevelFor(1),
    isNull,
  );
});
```

另加三个独立测试：旧时间戳不能覆盖新值、`leftSeconds == 0` 删除对应键、`reset()` 返回空快照。

- [ ] **Step 2: 运行测试并确认类型尚不存在**

Run: `flutter test test/combat_buff_tracker_test.dart`

Expected: FAIL，提示 `CombatBuffTracker` 等符号未定义。

- [ ] **Step 3: 实现最小纯 Dart 跟踪器**

`combat_buff_tracker.dart` 使用命名常量和记录键：

```dart
const int combatAttackBuffType = 1;
const int combatDefenseBuffType = 2;

class CombatBuffSample {
  const CombatBuffSample({
    required this.robotId,
    required this.buffType,
    required this.level,
    required this.leftSeconds,
    required this.receivedAt,
  });

  final int robotId;
  final int buffType;
  final int level;
  final int leftSeconds;
  final DateTime receivedAt;
}

class CombatBuffLevels {
  const CombatBuffLevels({this.attack = const {}, this.defense = const {}});

  final Map<int, int> attack;
  final Map<int, int> defense;
  int? attackLevelFor(int robotId) => attack[robotId];
  int? defenseLevelFor(int robotId) => defense[robotId];
}
```

`observe` 只接受类型 1/2 和非负剩余时间；负的类型 2 `level` 必须保留。缓存截止时间为 `receivedAt + Duration(seconds: leftSeconds)`，同键旧时间戳直接忽略。`snapshot` 过滤 `expiresAt <= now` 的记录并返回不可修改 Map。

- [ ] **Step 4: 验证 Buff 测试与静态分析**

Run: `flutter test test/combat_buff_tracker_test.dart`

Expected: PASS。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 5: 提交 Buff 跟踪器**

```bash
git add lib/features/dashboard/logic/combat_buff_tracker.dart test/combat_buff_tracker_test.dart
git commit -m "feat: track active combat buffs"
```

---

### Task 3: 按当前操作手身份校正斩杀线

**Files:**
- Modify: `lib/features/dashboard/logic/notification_rule_models.dart`
- Modify: `lib/features/dashboard/logic/kill_line_notification_tracker.dart`
- Modify: `lib/features/settings/domain/kill_estimate_config.dart`
- Modify: `test/notification_rule_engine_test.dart`

**Interfaces:**
- Consumes: `CombatBuffLevels`、`UnitHealthSample.selectedRobotId`、`KillEstimateConfig`。
- Produces: `UnitHealthSample.combatBuffs`；`KillEstimateConfig.expectedProjectilesForDamage(int currentHealth, double projectileDamage)`；身份驱动的斩杀线事件。

- [ ] **Step 1: 写失败测试覆盖武器映射、Buff 和工程撞击**

在 `test/notification_rule_engine_test.dart` 新增独立测试：

```dart
test('uses logged-in weapon and combat buffs for kill line', () {
  final now = DateTime(2026, 7, 22, 12);
  final buffs = CombatBuffLevels(
    attack: const {1: 150},
    defense: const {101: 25},
  );
  final events = _handleKillLineForRobot(
    selectedRobotId: 1,
    targetHealth: 180,
    buffs: buffs,
    timestamp: now,
  );
  expect(events.single.detail, contains('预计还需'));
  expect(events.single.headline, '敌方 1 号机器人进入斩杀线');
});

test('engineer uses defense-adjusted collision damage', () {
  final now = DateTime(2026, 7, 22, 12);
  final events = _handleKillLineForRobot(
    selectedRobotId: 2,
    targetHealth: 1,
    buffs: const CombatBuffLevels(defense: {101: 50}),
    timestamp: now,
  );
  expect(events.single.detail, contains('一次撞击扣血可清空当前血量'));
});
```

再增加：英雄攻击工程目标仍使用 42mm；3/4/6/7 使用 17mm；攻击 Buff 不修正工程撞击；99% 防御导致撞击最终伤害为 0 时不触发；固定血量和百分比模式继续通过。

- [ ] **Step 2: 运行斩杀线测试并确认旧目标索引逻辑失败**

Run: `flutter test test/notification_rule_engine_test.dart --plain-name "kill line"`

Expected: FAIL，旧代码仍使用 `index == 0` 选择 42mm，且没有 Buff 或工程撞击输入。

- [ ] **Step 3: 扩展纯输入模型和伤害估算接口**

在 `UnitHealthSample` 增加默认空快照：

```dart
this.combatBuffs = const CombatBuffLevels(),

final CombatBuffLevels combatBuffs;
```

在 `KillEstimateConfig` 增加：

```dart
int? expectedProjectilesForDamage({
  required int currentHealth,
  required double projectileDamage,
}) {
  if (currentHealth <= 0) return 0;
  final expectedDamage = projectileDamage * hitRate;
  if (expectedDamage <= 0) return null;
  return math.max(1, (currentHealth / expectedDamage).ceil());
}
```

现有 `expectedProjectiles` 委托给该方法，保持其他调用兼容。

- [ ] **Step 4: 实现身份与 Buff 伤害计算**

在斩杀线跟踪器使用当前 ID 的百位以下部分：`1` 为 42mm，`3/4/6/7` 为 17mm，`2` 为撞击。弹丸最终伤害为：

```dart
final ownBlue = selectedRobotId >= 100;
final targetRobotId = notificationRobotBaseIds[index] + (ownBlue ? 0 : 100);
final attackMultiplier = (buffs.attackLevelFor(selectedRobotId) ?? 100) / 100;
final defenseFraction = (buffs.defenseLevelFor(targetRobotId) ?? 0) / 100;
final damage = (baseDamage * attackMultiplier * (1 - defenseFraction)).round();
```

工程撞击使用：

```dart
const collisionBaseDamage = 2;
final damage = (collisionBaseDamage * (1 - defenseFraction)).round();
```

标题使用“敌方 X 号机器人进入斩杀线”；弹丸详情使用“预计还需 N 发弹丸”，工程详情使用“一次撞击扣血可清空当前血量”。保留现有冷却与重新武装状态。

- [ ] **Step 5: 验证斩杀线与回归测试**

Run: `flutter test test/notification_rule_engine_test.dart`

Expected: PASS。

Run: `flutter test test/kill_estimate_config_test.dart`

Expected: PASS。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 6: 提交斩杀线校正**

```bash
git add lib/features/dashboard/logic/notification_rule_models.dart lib/features/dashboard/logic/kill_line_notification_tracker.dart lib/features/settings/domain/kill_estimate_config.dart test/notification_rule_engine_test.dart
git commit -m "feat: correct operator kill-line estimates"
```

---

### Task 4: 敌方复活分类与付费复活着重提示

**Files:**
- Modify: `lib/features/dashboard/logic/notification_rule_engine.dart`
- Modify: `lib/features/dashboard/logic/notification_rule_models.dart`
- Modify: `test/notification_rule_engine_test.dart`
- Modify: `test/notification_rule_profile_test.dart`

**Interfaces:**
- Produces: `RespawnDurationBounds`、`expectedFreeRespawnBounds(...)`；同时保存普通/最快免费复活边界与基地低血量记录的敌方战亡状态；统一敌方复活标题；付费复活使用 `enemyBoughtRespawn`。

- [ ] **Step 1: 写失败测试覆盖四类结果和容差**

在 `test/notification_rule_engine_test.dart` 将复活测试拆成普通免费、加速免费、付费和不确定四个测试。付费测试的关键断言：

```dart
expect(event.type, NotificationEventType.enemyBoughtRespawn);
expect(event.headline, '敌方 1 号机器人复活');
expect(event.detail, contains('敌方复活用时 2 秒'));
expect(event.detail, contains('推断为付费复活'));
```

加速测试分别构造基地始终高于 2000 和战亡期间降到 2000 的快照，断言详情为“推断为补给区加速免费复活”和“推断为基地低血量加速免费复活”。边界测试使用 `toleranceMilliseconds: 1500`，验证容差内不会误判付费。

- [ ] **Step 2: 运行复活测试并确认旧二分类失败**

Run: `flutter test test/notification_rule_engine_test.dart --plain-name "respawn"`

Expected: FAIL，旧实现只有“买活/免费复活”二分类且标题为角色名称。

- [ ] **Step 3: 保存两条时间边界与战亡区间原因**

将死亡记录改为明确字段：

```dart
class _DeathRecord {
  const _DeathRecord({
    required this.at,
    required this.normalDuration,
    required this.fastestDuration,
    required this.baseLowDuringDeath,
  });

  final DateTime at;
  final Duration? normalDuration;
  final Duration? fastestDuration;
  final bool baseLowDuringDeath;
}
```

敌方保持 0 HP 的每个血量快照都更新 `baseLowDuringDeath`。普通速率固定取配置的 `normalProgressPerSecond`，最快速率取 `acceleratedProgressPerSecond`，不得只按死亡瞬间基地血量选其中一个。

新增边界模型和计算函数：

```dart
class RespawnDurationBounds {
  const RespawnDurationBounds({
    required this.normal,
    required this.fastest,
  });

  final Duration normal;
  final Duration fastest;
}
```

`expectedFreeRespawnBounds(...)` 先按现有公式计算一次所需进度，再分别除以普通和加快速率。保留 `expectedFreeRespawnDuration(...)`，使其返回 `expectedFreeRespawnBounds(...)?.normal`，避免破坏现有设置和测试调用。

- [ ] **Step 4: 实现三段分类与统一文案**

分类顺序固定为：

```dart
if (elapsed + tolerance < fastest) {
  return paidRespawn;
}
if (elapsed + tolerance < normal) {
  return acceleratedFreeRespawn;
}
return normalFreeRespawn;
```

必要数据缺失时返回 `enemyRespawned`，详情写“敌方复活用时 X 秒，复活方式不确定”。只有付费分支增加 `_enemyBuybackCounts[index]` 并返回 `enemyBoughtRespawn`。

- [ ] **Step 5: 验证复活分类和默认严重级别**

Run: `flutter test test/notification_rule_engine_test.dart test/notification_rule_profile_test.dart`

Expected: PASS；官方档案中普通复活为 `INFO`，付费复活为 `CRITICAL`。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 6: 提交复活通知校正**

```bash
git add lib/features/dashboard/logic/notification_rule_engine.dart lib/features/dashboard/logic/notification_rule_models.dart test/notification_rule_engine_test.dart test/notification_rule_profile_test.dart
git commit -m "feat: classify enemy respawn methods"
```

---

### Task 5: 存在性明确的模块状态与通知转换

**Files:**
- Create: `lib/features/dashboard/logic/module_status_monitor.dart`
- Create: `test/module_status_monitor_test.dart`
- Modify: `lib/features/dashboard/logic/notification_protocol_tracker.dart`
- Modify: `lib/features/dashboard/logic/notification_rule_engine.dart`
- Modify: `test/notification_rule_engine_test.dart`

**Interfaces:**
- Produces: `RobotModuleType`、`ModuleAvailability`、`ModuleStatusReading`、`ModuleStatusTransition`、`ModuleStatusMonitorState`、`ModuleStatusMonitorController.observe(ModuleStatusReading)`、`reset()`、`moduleStatusMonitorProvider`。
- Consumers: Task 6 的侧面板和 Task 7 的 Protobuf 运行时。

- [ ] **Step 1: 写失败测试覆盖首次快照和字段存在性**

创建 `test/module_status_monitor_test.dart`，关键场景为：

```dart
test('reports an explicitly offline module in the first snapshot', () {
  final controller = ModuleStatusMonitorController();
  final transitions = controller.observe(const ModuleStatusReading({
    RobotModuleType.videoTransmission: ModuleAvailability.offline,
  }));
  expect(transitions.single.becameOffline, isTrue);
  expect(controller.state.hasOffline, isTrue);
});

test('missing fields retain the last valid state', () {
  final controller = ModuleStatusMonitorController();
  controller.observe(const ModuleStatusReading({
    RobotModuleType.armor: ModuleAvailability.offline,
  }));
  controller.observe(const ModuleStatusReading({}));
  expect(controller.state.statuses[RobotModuleType.armor], ModuleAvailability.offline);
});
```

另加：首次在线不产生转换、`0/2` 映射后不重复、离线到在线产生恢复、`reset()` 清空当前连接状态。

- [ ] **Step 2: 运行模块测试并确认新模型尚不存在**

Run: `flutter test test/module_status_monitor_test.dart`

Expected: FAIL，提示模块状态类型未定义。

- [ ] **Step 3: 实现模块状态控制器**

控制器只保存已经明确出现过的字段，并返回状态变化：

```dart
class ModuleStatusMonitorController
    extends StateNotifier<ModuleStatusMonitorState> {
  ModuleStatusMonitorController() : super(const ModuleStatusMonitorState());

  List<ModuleStatusTransition> observe(ModuleStatusReading reading) {
    final next = Map<RobotModuleType, ModuleAvailability>.from(state.statuses);
    final transitions = <ModuleStatusTransition>[];
    for (final entry in reading.statuses.entries) {
      final previous = next[entry.key];
      next[entry.key] = entry.value;
      final transition = ModuleStatusTransition.from(previous, entry);
      if (transition != null) transitions.add(transition);
    }
    state = ModuleStatusMonitorState(statuses: Map.unmodifiable(next));
    return transitions;
  }

  void reset() => state = const ModuleStatusMonitorState();
}

final moduleStatusMonitorProvider = StateNotifierProvider<
  ModuleStatusMonitorController,
  ModuleStatusMonitorState
>((ref) => ModuleStatusMonitorController());
```

`ModuleStatusTransition.from` 在 `previous == null && current == offline`、`online -> offline`、`offline -> online` 时返回转换；首次在线和同类状态不返回。

- [ ] **Step 4: 将通知跟踪器改为消费转换**

删除 `NotificationProtocolTracker` 内部 `_previousModuleStatus`。新增：

```dart
RuleNotificationEvent moduleEvent(
  ModuleStatusTransition transition,
  DateTime timestamp,
)
```

离线标题为“XX 模块离线”，恢复标题为“XX 模块恢复在线”；离线去重键为 `module-offline-${transition.module.name}`，恢复事件的 `recoveryKey` 使用同一离线键。`NotificationRuleEngine` 只转发该转换，不保存模块副本。

- [ ] **Step 5: 验证模块逻辑与通知映射**

Run: `flutter test test/module_status_monitor_test.dart test/notification_rule_engine_test.dart`

Expected: PASS。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 6: 提交模块状态核心**

```bash
git add lib/features/dashboard/logic/module_status_monitor.dart lib/features/dashboard/logic/notification_protocol_tracker.dart lib/features/dashboard/logic/notification_rule_engine.dart test/module_status_monitor_test.dart test/notification_rule_engine_test.dart
git commit -m "feat: track explicit module status transitions"
```

---

### Task 6: 主仪表盘持久模块状态面板

**Files:**
- Create: `lib/features/dashboard/presentation/module_status_strings.dart`
- Create: `lib/features/dashboard/presentation/widgets/module_status_panel.dart`
- Create: `lib/features/dashboard/presentation/widgets/dashboard_side_panel.dart`
- Create: `test/dashboard_side_panel_test.dart`
- Modify: `lib/features/dashboard/presentation/dashboard_screen.dart`

**Interfaces:**
- Consumes: `moduleStatusMonitorProvider` 和 `ModuleStatusMonitorState.hasOffline`。
- Produces: `DashboardSidePanel`；离线时模块列表、全在线时原 `EventTimelinePanel`。

- [ ] **Step 1: 写失败 Widget 测试**

创建 `test/dashboard_side_panel_test.dart`，使用真实 `ModuleStatusMonitorController` 覆盖 Provider：

```dart
testWidgets('switches to module panel until every module recovers', (tester) async {
  final controller = ModuleStatusMonitorController();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      moduleStatusMonitorProvider.overrideWith((ref) => controller),
      gameStateProvider.overrideWith((ref) => GameStateNotifier()),
    ],
    child: const MaterialApp(home: Scaffold(body: DashboardSidePanel())),
  ));
  expect(find.text('事件时间轴'), findsOneWidget);

  controller.observe(const ModuleStatusReading({
    RobotModuleType.videoTransmission: ModuleAvailability.offline,
    RobotModuleType.armor: ModuleAvailability.online,
  }));
  await tester.pumpAndSettle();
  expect(find.text('模块状态'), findsOneWidget);
  expect(find.text('图传模块'), findsOneWidget);

  controller.observe(const ModuleStatusReading({
    RobotModuleType.videoTransmission: ModuleAvailability.online,
  }));
  await tester.pumpAndSettle();
  expect(find.text('事件时间轴'), findsOneWidget);
});
```

再加一个测试：模块离线通知事件设置为关闭时，直接更新模块控制器仍显示模块面板。

再用同一个 `GameStateNotifier` 在模块面板显示期间注入事件，并在模块恢复后验证事件仍存在：

```dart
final event = Event(eventId: 14, param: '');
gameState.handleEnvelope(ProtobufEnvelope(
  topic: topicEvent,
  messageType: topicEvent,
  protobufMessage: event,
  rawBytes: event.writeToBuffer(),
  timestamp: DateTime(2026, 7, 22, 12),
));
controller.observe(const ModuleStatusReading({
  RobotModuleType.videoTransmission: ModuleAvailability.online,
}));
await tester.pumpAndSettle();
expect(find.text('四级装配请求'), findsOneWidget);
```

- [ ] **Step 2: 运行 Widget 测试并确认组件尚不存在**

Run: `flutter test test/dashboard_side_panel_test.dart`

Expected: FAIL，提示 `DashboardSidePanel` 未定义。

- [ ] **Step 3: 实现 Material 3 模块列表**

`ModuleStatusPanel` 使用现有 `Card`、`colorScheme.errorContainer`、`surfaceContainerLow` 和 `textTheme`。排序规则固定为离线在前、同状态按 `RobotModuleType.values` 顺序。每行显示模块名称和“离线/在线”，不显示协议值 `0/1/2`。

`DashboardSidePanel` 使用：

```dart
class DashboardSidePanel extends ConsumerWidget {
  const DashboardSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(moduleStatusMonitorProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: modules.hasOffline
          ? const ModuleStatusPanel(key: ValueKey('module-status'))
          : const EventTimelinePanel(key: ValueKey('event-timeline')),
    );
  }
}
```

- [ ] **Step 4: 接入主仪表盘侧面区域**

在 `dashboard_screen.dart` 将：

```dart
Expanded(child: EventTimelinePanel()),
```

替换为：

```dart
Expanded(child: DashboardSidePanel()),
```

移除不再需要的 `event_timeline_panel.dart` 直接导入，改为导入 `dashboard_side_panel.dart`。

- [ ] **Step 5: 验证面板切换、布局和静态分析**

Run: `flutter test test/dashboard_side_panel_test.dart test/dashboard_v012_test.dart`

Expected: PASS，窄高度和固定桌面画布无溢出。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 6: 提交持久模块面板**

```bash
git add lib/features/dashboard/presentation/module_status_strings.dart lib/features/dashboard/presentation/widgets/module_status_panel.dart lib/features/dashboard/presentation/widgets/dashboard_side_panel.dart lib/features/dashboard/presentation/dashboard_screen.dart test/dashboard_side_panel_test.dart
git commit -m "feat: show persistent offline module panel"
```

---

### Task 7: MQTT 运行时接入 Buff、模块字段和重置边界

**Files:**
- Modify: `lib/core/constants/protocol_constants.dart`
- Modify: `lib/features/dashboard/logic/notification_providers.dart`
- Modify: `lib/features/dashboard/logic/notification_rule_engine.dart`
- Modify: `lib/features/dashboard/logic/module_status_monitor.dart`
- Modify: `test/notification_runtime_test.dart`
- Modify: `test/notification_runtime_widget_test.dart`

**Interfaces:**
- Consumes: `CombatBuffTracker`、`ModuleStatusMonitorController`、生成的 `Buff` 和 `RobotModuleStatus`。
- Produces: `moduleStatusMonitorProvider`；运行时 Buff 接入；presence-aware 模块读数；断线/比赛/身份重置。

- [ ] **Step 1: 写失败测试锁定必需订阅与 Protobuf 字段存在性**

在 `test/notification_runtime_test.dart` 增加：

```dart
test('notification runtime requires Buff topic', () {
  expect(notificationRequiredTopics, contains(topicBuff));
});

test('module mapper ignores absent protobuf fields', () {
  final message = RobotModuleStatus(videoTransmission: 0, armor: 1);
  final reading = moduleStatusReadingFromProtocol(message);
  expect(reading.statuses.keys, {
    RobotModuleType.videoTransmission,
    RobotModuleType.armor,
  });
  expect(reading.statuses, isNot(contains(RobotModuleType.bigShooter)));
});
```

再加映射测试：协议值 `2` 映射为 `offline`，未知值忽略。

- [ ] **Step 2: 运行运行时测试并确认订阅及映射缺失**

Run: `flutter test test/notification_runtime_test.dart`

Expected: FAIL，`notificationRequiredTopics` 不含 `topicBuff` 且 mapper 不存在。

- [ ] **Step 3: 接入 Buff 与存在性明确的模块映射**

将 `topicBuff` 加入 `notificationRequiredTopics`。在 `_handleEnvelope` 增加：

```dart
case final Buff buff:
  _engine.observeBuff(CombatBuffSample(
    robotId: buff.robotId,
    buffType: buff.buffType,
    level: buff.buffLevel,
    leftSeconds: buff.buffLeftTime,
    receivedAt: envelope.timestamp,
  ));
```

模块 mapper 对每个字段调用 `hasPowerManager()`、`hasRfid()` 等存在性方法，只把存在且值为 `0/1/2` 的字段放入 `ModuleStatusReading`。运行时先调用模块控制器 `observe`，再把返回的每个转换交给规则引擎生成通知。

- [ ] **Step 4: 在血量处理时使用有效 Buff 快照**

构造 `UnitHealthSample` 时增加：

```dart
combatBuffs: _engine.combatBuffsAt(timestamp),
```

Buff 查询时间必须使用信封时间，不能使用 `DateTime.now()`，保证测试、回放和实时时间口径一致。

- [ ] **Step 5: 接入连接、比赛和身份重置**

MQTT 离开 `connected` 状态时调用 Buff 重置和模块控制器 `reset()`；新局或 `previous.currentStage == stageInMatch && status.currentStage != stageInMatch` 时清理比赛级状态，覆盖正常及异常离开比赛阶段。监听 `selectedRobotIdProvider`，身份变化时执行同样的比赛级状态清理，防止红蓝阵营和本机攻击 Buff 串用。

- [ ] **Step 6: 验证运行时与全局通知回归**

Run: `flutter test test/notification_runtime_test.dart test/notification_runtime_widget_test.dart test/notification_rule_engine_test.dart test/module_status_monitor_test.dart`

Expected: PASS。

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: 提交运行时接入**

```bash
git add lib/core/constants/protocol_constants.dart lib/features/dashboard/logic/notification_providers.dart lib/features/dashboard/logic/notification_rule_engine.dart test/notification_runtime_test.dart test/notification_runtime_widget_test.dart
git commit -m "feat: connect notification accuracy to live protocol"
```

---

### Task 8: 完整回归、自审计与 feature_spec 收口

**Files:**
- Modify: `feature_spec.md`
- Review: all files changed by Tasks 1–7

**Interfaces:**
- Produces: 完整 v0.1.5 进度、准确 Changelog、验证结果和可交付提交。

- [ ] **Step 1: 格式化本版本 Dart 文件**

Run: `dart format lib/features/dashboard/logic/combat_buff_tracker.dart lib/features/dashboard/logic/module_status_monitor.dart lib/features/dashboard/logic/kill_line_notification_tracker.dart lib/features/dashboard/logic/notification_rule_engine.dart lib/features/dashboard/logic/notification_protocol_tracker.dart lib/features/dashboard/logic/notification_rule_models.dart lib/features/dashboard/logic/notification_providers.dart lib/features/dashboard/presentation/module_status_strings.dart lib/features/dashboard/presentation/widgets/module_status_panel.dart lib/features/dashboard/presentation/widgets/dashboard_side_panel.dart lib/features/dashboard/presentation/dashboard_screen.dart lib/features/settings/domain/kill_estimate_config.dart lib/features/settings/domain/notification_rule_profile.dart test/combat_buff_tracker_test.dart test/module_status_monitor_test.dart test/dashboard_side_panel_test.dart test/notification_rule_engine_test.dart test/notification_rule_profile_test.dart test/notification_runtime_test.dart test/notification_runtime_widget_test.dart`

Expected: 命令成功，无格式错误。

- [ ] **Step 2: 运行针对性测试**

Run: `flutter test test/combat_buff_tracker_test.dart test/module_status_monitor_test.dart test/dashboard_side_panel_test.dart test/notification_rule_engine_test.dart test/notification_rule_profile_test.dart test/notification_runtime_test.dart test/notification_runtime_widget_test.dart`

Expected: 全部 PASS。

- [ ] **Step 3: 运行全量验证**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test`

Expected: 全部测试 PASS，记录最终测试数量。

- [ ] **Step 4: 执行项目自审计**

逐项检查：函数不超过 50 行、无 Widget 直接解析 MQTT/Protobuf、无硬编码新增 UI 文案、导入排序正确、无显式无说明 `!`、未知协议字段安全忽略、所有重置路径释放临时状态、未修改视频链路、`docs/presentations/` 未暂存。

- [ ] **Step 5: 完成 feature_spec 结果记录**

在 `feature_spec.md`：

- 将 v0.1.5 所有已完成任务改为 `[x]`。
- 顶部接手摘要改为 v0.1.5 已实现、待发布。
- 写明现有基础、实际改动和不处理范围。
- 附录 E 的 0.1.5 行使用“新增/修复/优化/文档”前缀记录真实结果。
- 写入 `flutter analyze` 零问题和全量测试实际通过数量。

- [ ] **Step 6: 文档写入后再次验证静态分析**

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 7: 提交 v0.1.5 收口文档**

```bash
git add feature_spec.md
git commit -m "docs: complete v0.1.5 notification accuracy"
```
