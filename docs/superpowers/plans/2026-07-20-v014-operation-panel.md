# v0.1.4 Operation Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct every retained operation-panel command, drive remote actions and engineering assembly from real protocol state, and guarantee that repeated commands stop at every lifecycle boundary.

**Architecture:** Move Protobuf construction and MQTT publication into a data-layer command service. A Riverpod `StateNotifier` consumes identity-scoped `RobotDynamicStatus` and `TechCoreMotionStateSync`, owns all repeat timers, and exposes immutable primitives to presentation widgets. The UI maps structured feedback to centralized Chinese strings and owns only rendering/animation.

**Tech Stack:** Dart 3.x, Flutter 3.x, flutter_riverpod 2.6.1, protobuf 6.0.0, flutter_test.

## Global Constraints

- Current development version is `0.1.4`; `pubspec.yaml` is the version authority.
- Keep every function at or below 50 lines.
- Widgets must not call `MqttService` or construct/publish command Protobuf messages.
- All protocol numbers use named constants in `protocol_constants.dart`.
- All new UI strings live in `operation_panel_strings.dart`.
- Unknown or missing protocol state disables the affected operation without inventing a reason.
- Timer work stops on completion, cancellation, protocol reset, MQTT disconnect, identity change and provider disposal.
- Run `flutter analyze` after every file-write batch.
- Do not stage or commit `docs/presentations/`; it is a local temporary artifact.

---

## File Structure

- Create `lib/features/dashboard/data/operation_command_service.dart`: construct and publish operation Protobuf messages through an injected callback.
- Create `lib/features/dashboard/domain/operation_panel_state.dart`: immutable role, telemetry, pulse-token and structured feedback state.
- Create `lib/features/dashboard/logic/operation_panel_controller.dart`: protocol synchronization, identity reset, repeat scheduling and operation guards.
- Create `lib/features/dashboard/presentation/operation_panel_strings.dart`: operation labels, status descriptions and feedback mapping.
- Create `lib/features/dashboard/presentation/widgets/operation_panel_sections.dart`: engineer/combat sections and reusable pulsing action button.
- Modify `lib/features/dashboard/presentation/widgets/operation_panel.dart`: thin provider host and section dispatch.
- Modify `lib/core/constants/protocol_constants.dart`: named command/operation constants and remote ammo unit.
- Create `test/operation_command_service_test.dart`.
- Create `test/operation_panel_controller_test.dart`.
- Modify `test/operation_panel_test.dart`.
- Modify `feature_spec.md` at the end of every completed Phase and at final verification.

---

### Task 1: Command constants and MQTT operation service

**Files:**
- Modify: `lib/core/constants/protocol_constants.dart`
- Create: `lib/features/dashboard/data/operation_command_service.dart`
- Test: `test/operation_command_service_test.dart`
- Modify: `feature_spec.md`

**Interfaces:**
- Consumes: `void Function(String topic, GeneratedMessage message)`.
- Produces: `OperationCommandService.exchange17mm`, `exchange42mm`, `remoteHeal`, `remoteAmmo`, `startExchange`, `confirmAssembly`, `cancelAssembly`.

- [ ] **Step 1: Write failing protocol-message tests**

```dart
final published = <({String topic, GeneratedMessage message})>[];
final service = OperationCommandService(
  publish: (topic, message) => published.add((topic: topic, message: message)),
);

service.exchange42mm(30);
final command = published.single.message as CommonCommand;
expect(published.single.topic, topicCommonCommand);
expect(command.cmdType, commonCommandExchange42mm);
expect(command.param, 30);
```

Use the following explicit call matrix in the same test file:

```dart
service
  ..exchange17mm(20)
  ..exchange42mm(30)
  ..remoteHeal()
  ..remoteAmmo()
  ..startExchange(4)
  ..confirmAssembly()
  ..cancelAssembly();

expect(_commonAt(published, 0), (type: commonCommandExchange17mm, param: 20));
expect(_commonAt(published, 1), (type: commonCommandExchange42mm, param: 30));
expect(_commonAt(published, 2), (type: commonCommandRemoteHeal, param: 0));
expect(
  _commonAt(published, 3),
  (type: commonCommandRemoteAmmo, param: remoteAmmoExchangeRounds),
);
expect(_assemblyAt(published, 4), (operation: assemblyOperationStartExchange, difficulty: 4));
expect(_assemblyAt(published, 5), (operation: assemblyOperationConfirm, difficulty: 0));
expect(_assemblyAt(published, 6), (operation: assemblyOperationCancel, difficulty: 0));
```

- [ ] **Step 2: Run the test and verify failure**

Run: `flutter test test/operation_command_service_test.dart --reporter expanded`

Expected: FAIL because `OperationCommandService` and named command constants do not exist.

- [ ] **Step 3: Add named protocol constants**

```dart
const int commonCommandExchange17mm = 1;
const int commonCommandExchange42mm = 2;
const int commonCommandRemoteAmmo = 5;
const int commonCommandRemoteHeal = 6;
const int assemblyOperationStartExchange = 0;
const int assemblyOperationConfirm = 1;
const int assemblyOperationCancel = 2;
const int remoteAmmoExchangeRounds = 100;
```

- [ ] **Step 4: Implement the injected command service**

```dart
typedef OperationMessagePublisher = void Function(
  String topic,
  GeneratedMessage message,
);

class OperationCommandService {
  const OperationCommandService({required OperationMessagePublisher publish})
      : _publish = publish;

  final OperationMessagePublisher _publish;

  void exchange17mm(int rounds) => _common(commonCommandExchange17mm, rounds);
  void exchange42mm(int rounds) => _common(commonCommandExchange42mm, rounds);
  void remoteHeal() => _common(commonCommandRemoteHeal, 0);
  void remoteAmmo() => _common(commonCommandRemoteAmmo, remoteAmmoExchangeRounds);
  void startExchange(int difficulty) =>
      _assembly(assemblyOperationStartExchange, difficulty);
  void confirmAssembly() => _assembly(assemblyOperationConfirm, 0);
  void cancelAssembly() => _assembly(assemblyOperationCancel, 0);

  void _common(int type, int param) {
    _publish(topicCommonCommand, CommonCommand(cmdType: type, param: param));
  }

  void _assembly(int operation, int difficulty) {
    _publish(
      topicAssemblyCommand,
      AssemblyCommand(operation: operation, difficulty: difficulty),
    );
  }
}
```

- [ ] **Step 5: Run tests and analysis**

Run: `flutter test test/operation_command_service_test.dart --reporter expanded`

Expected: PASS, all emitted messages have the exact expected Topic and fields.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 6: Mark Phase 1 Tasks 1–3 complete and commit**

Update the matching `feature_spec.md` rows to `[x]`, then commit only the Task 1 files:

```powershell
git add -- lib/core/constants/protocol_constants.dart lib/features/dashboard/data/operation_command_service.dart test/operation_command_service_test.dart feature_spec.md
git commit -m "fix: correct operation command parameters"
```

---

### Task 2: Immutable operation state and controller

**Files:**
- Create: `lib/features/dashboard/domain/operation_panel_state.dart`
- Create: `lib/features/dashboard/logic/operation_panel_controller.dart`
- Test: `test/operation_panel_controller_test.dart`
- Modify: `feature_spec.md`

**Interfaces:**
- Consumes: `OperationCommandService`, `RobotDynamicStatus`, `TechCoreMotionStateSync`, selected robot ID and MQTT connected state.
- Produces: `operationPanelControllerProvider`, `OperationPanelController.handleMessage`, `setConnected`, `resetIdentity`, `selectAmmoQuantity`, `toggleExchange`, `toggleAutoConfirm`, `cancelAssembly`, and combat operation methods.

- [ ] **Step 1: Write failing state-transition tests**

```dart
controller.handleMessage(RobotDynamicStatus(
  canRemoteHeal: true,
  canRemoteAmmo: false,
));
expect(controller.state.remoteHealEnabled, isTrue);
expect(controller.state.remoteHealPulseToken, 0);

controller.handleMessage(RobotDynamicStatus(canRemoteHeal: false));
controller.handleMessage(RobotDynamicStatus(canRemoteHeal: true));
expect(controller.state.remoteHealPulseToken, 1);
```

Add these named cases with explicit outcomes:

```dart
test('first telemetry snapshot establishes baseline without pulse', () {
  controller.handleMessage(RobotDynamicStatus(
    canRemoteHeal: true,
    canRemoteAmmo: true,
  ));
  expect(controller.state.remoteHealPulseToken, 0);
  expect(controller.state.remoteAmmoPulseToken, 0);
});

test('identity reset clears identity-scoped telemetry and timers', () {
  controller.resetIdentity();
  expect(controller.state.telemetryKnown, isFalse);
  expect(controller.state.techCoreKnown, isFalse);
  expect(controller.state.activeDifficulty, isNull);
  expect(controller.state.autoConfirmArmed, isFalse);
  expect(repeaters.every((repeater) => repeater.isCancelled), isTrue);
});

test('tech core completion stops confirmation repeat', () {
  controller.toggleAutoConfirm();
  controller.handleMessage(TechCoreMotionStateSync(
    maximumDifficultyLevel: 4,
    basicState: 2,
    remainTimeAll: 20,
  ));
  expect(confirmRepeater.isCancelled, isFalse);
  controller.handleMessage(TechCoreMotionStateSync(
    maximumDifficultyLevel: 4,
    basicState: 3,
    putinState: 1,
    moveState: 1,
    rotateState: 1,
  ));
  expect(confirmRepeater.isCancelled, isTrue);
  expect(controller.state.autoConfirmArmed, isFalse);
});
```

Use separate tests named `false to true increments only the matching pulse token`, `motion state stops start-exchange repeat`, `active to initial reset stops all repeats`, `disconnect stops all repeats`, `cancel sends cancel and stops all repeats`, and `dispose cancels all repeaters`; each asserts the exact affected token, published operation and `isCancelled` value.

- [ ] **Step 2: Run the test and verify failure**

Run: `flutter test test/operation_panel_controller_test.dart --reporter expanded`

Expected: FAIL because the state and controller do not exist.

- [ ] **Step 3: Implement immutable state primitives**

```dart
enum OperationRobotRole { hero, engineer, infantry, unsupported }
enum OperationFeedbackType { commandSent, autoConfirmArmed, stopped, failed }

class TechCorePanelState {
  const TechCorePanelState({
    required this.maximumDifficulty,
    required this.basicState,
    required this.putinDone,
    required this.moveDone,
    required this.rotateDone,
    required this.remainingTotalSeconds,
    required this.remainingStepSeconds,
  });

  const TechCorePanelState.unknown()
      : maximumDifficulty = 0,
        basicState = 0,
        putinDone = false,
        moveDone = false,
        rotateDone = false,
        remainingTotalSeconds = 0,
        remainingStepSeconds = 0;

  final int maximumDifficulty;
  final int basicState;
  final bool putinDone;
  final bool moveDone;
  final bool rotateDone;
  final int remainingTotalSeconds;
  final int remainingStepSeconds;

  bool get isCompleted => putinDone && moveDone && rotateDone;
  bool get isFlowActive => !isCompleted && (basicState == 2 || basicState == 3);
}

class OperationFeedback {
  const OperationFeedback(this.serial, this.type, [this.error]);
  final int serial;
  final OperationFeedbackType type;
  final Object? error;
}

const _keepOperationValue = Object();

class OperationPanelState {
  const OperationPanelState({
    this.telemetryKnown = false,
    this.remoteHealEnabled = false,
    this.remoteAmmoEnabled = false,
    this.remoteHealPulseToken = 0,
    this.remoteAmmoPulseToken = 0,
    this.ammoQuantity = 10,
    this.autoConfirmArmed = false,
    this.activeDifficulty,
    this.techCoreKnown = false,
    this.techCore = const TechCorePanelState.unknown(),
    this.feedback,
  });

  final bool telemetryKnown;
  final bool remoteHealEnabled;
  final bool remoteAmmoEnabled;
  final int remoteHealPulseToken;
  final int remoteAmmoPulseToken;
  final int ammoQuantity;
  final bool autoConfirmArmed;
  final int? activeDifficulty;
  final bool techCoreKnown;
  final TechCorePanelState techCore;
  final OperationFeedback? feedback;

  OperationPanelState copyWith({
    bool? telemetryKnown,
    bool? remoteHealEnabled,
    bool? remoteAmmoEnabled,
    int? remoteHealPulseToken,
    int? remoteAmmoPulseToken,
    int? ammoQuantity,
    bool? autoConfirmArmed,
    Object? activeDifficulty = _keepOperationValue,
    bool? techCoreKnown,
    TechCorePanelState? techCore,
    Object? feedback = _keepOperationValue,
  }) => OperationPanelState(
    telemetryKnown: telemetryKnown ?? this.telemetryKnown,
    remoteHealEnabled: remoteHealEnabled ?? this.remoteHealEnabled,
    remoteAmmoEnabled: remoteAmmoEnabled ?? this.remoteAmmoEnabled,
    remoteHealPulseToken: remoteHealPulseToken ?? this.remoteHealPulseToken,
    remoteAmmoPulseToken: remoteAmmoPulseToken ?? this.remoteAmmoPulseToken,
    ammoQuantity: ammoQuantity ?? this.ammoQuantity,
    autoConfirmArmed: autoConfirmArmed ?? this.autoConfirmArmed,
    activeDifficulty: identical(activeDifficulty, _keepOperationValue)
        ? this.activeDifficulty
        : activeDifficulty as int?,
    techCoreKnown: techCoreKnown ?? this.techCoreKnown,
    techCore: techCore ?? this.techCore,
    feedback: identical(feedback, _keepOperationValue)
        ? this.feedback
        : feedback as OperationFeedback?,
  );
}
```

Clamp `maximumDifficulty` to 0–4, normalize each step to a boolean, and clamp both remaining times to non-negative integers when converting from Protobuf. Do not retain mutable protobuf objects in state.

- [ ] **Step 4: Implement injectable repeat scheduling**

```dart
abstract interface class OperationRepeater {
  void cancel();
}

typedef OperationRepeatFactory = OperationRepeater Function(
  Duration interval,
  void Function() callback,
);
```

The production factory wraps `Timer.periodic`; tests use a manual repeater that exposes `tick()` and `isCancelled`.

- [ ] **Step 5: Implement controller guards and protocol handling**

```dart
void handleMessage(GeneratedMessage message) {
  switch (message) {
    case final RobotDynamicStatus status:
      _applyDynamicStatus(status);
    case final TechCoreMotionStateSync status:
      _applyTechCoreStatus(status);
  }
}
```

The first dynamic snapshot establishes a baseline without pulsing. Start-exchange repeats stop when Basic State leaves Initial. Confirm repeats run only while auto-confirm is armed and the flow is active; they stop on completed steps, active-to-initial reset, zero remaining time after activation, cancellation, disconnect, identity reset or disposal.

- [ ] **Step 6: Wire the Riverpod provider**

Create `operationCommandServiceProvider` from `mqttServiceProvider.publish`. The controller provider listens to `mqttMessageProvider`, `mqttConnectionStateSyncProvider`, and `selectedRobotIdProvider`; identity change calls `resetIdentity` before new identity telemetry is accepted.

- [ ] **Step 7: Run tests and analysis**

Run: `flutter test test/operation_panel_controller_test.dart --reporter expanded`

Expected: PASS, including manual repeater cancellation assertions.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 8: Mark Phase 2 complete and commit**

```powershell
git add -- lib/features/dashboard/domain/operation_panel_state.dart lib/features/dashboard/logic/operation_panel_controller.dart test/operation_panel_controller_test.dart feature_spec.md
git commit -m "feat: drive operations from protocol state"
```

---

### Task 3: Presentation strings, sections and single-pulse action button

**Files:**
- Create: `lib/features/dashboard/presentation/operation_panel_strings.dart`
- Create: `lib/features/dashboard/presentation/widgets/operation_panel_sections.dart`
- Modify: `lib/features/dashboard/presentation/widgets/operation_panel.dart`
- Test: `test/operation_panel_test.dart`
- Modify: `feature_spec.md`

**Interfaces:**
- Consumes: `OperationPanelState`, `OperationPanelController`, selected robot ID.
- Produces: role-correct combat/engineer UI and `_AvailabilityPulse` behavior keyed by pulse token.

- [ ] **Step 1: Replace existing widget expectations with failing behavior tests**

```dart
expect(find.text('请求复活'), findsNothing);
expect(find.text('远程买血'), findsOneWidget);
expect(find.text('远程买弹'), findsOneWidget);

final remoteAmmo = tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, '远程买弹'),
);
expect(remoteAmmo.onPressed, isNull);
```

Add these provider-driven widget assertions:

```dart
expect(find.text('请求复活'), findsNothing);
expect(find.text('英雄 · 42mm'), findsOneWidget);
expect(find.byKey(const ValueKey('remote-heal-pulse')), findsOneWidget);

await tester.pumpWidget(_engineerPanel(
  const OperationPanelState(
    techCoreKnown: true,
    techCore: TechCorePanelState(
      maximumDifficulty: 2,
      basicState: 2,
      putinDone: true,
      moveDone: false,
      rotateDone: false,
      remainingTotalSeconds: 18,
      remainingStepSeconds: 4,
    ),
  ),
));
expect(find.text('Lv.3'), findsNothing);
expect(find.text('已放入'), findsOneWidget);
expect(find.text('等待平移'), findsOneWidget);
expect(tester.takeException(), isNull);
```

- [ ] **Step 2: Run widget tests and verify failure**

Run: `flutter test test/operation_panel_test.dart --reporter expanded`

Expected: FAIL because the current UI still shows the respawn button and ignores telemetry.

- [ ] **Step 3: Centralize operation strings**

```dart
const operationRemoteHealLabel = '远程买血';
const operationRemoteAmmoLabel = '远程买弹';
const operationWaitingTelemetryReason = '等待机器人实时状态';
const operationRemoteHealUnavailableReason = '裁判系统当前不允许远程回血';
const operationRemoteAmmoUnavailableReason = '裁判系统当前不允许远程买弹';
const operationTechCoreWaiting = '等待科技核心状态';
const operationTechCoreMoving = '科技核心运动中';
const operationTechCoreArrived = '科技核心已到达';
const operationPutinDone = '已放入';
const operationPutinWaiting = '等待放入';
const operationMoveDone = '已平移';
const operationMoveWaiting = '等待平移';
const operationRotateDone = '已旋转';
const operationRotateWaiting = '等待旋转';
const operationSecondsUnit = '秒';
```

Define a total `String operationFeedbackText(OperationFeedback feedback)` switch covering every `OperationFeedbackType`; append `feedback.error` only for `failed`.

- [ ] **Step 4: Implement the pulsing action wrapper**

Use one `AnimationController` with a 700 ms forward animation. In `didUpdateWidget`, call `forward(from: 0)` only when `pulseToken` increases and the new token is greater than zero. Animate a low-alpha outer shadow; do not loop.

- [ ] **Step 5: Build focused combat and engineer sections**

Combat section renders three retained actions: normal ammo, remote heal and remote ammo. Engineer section renders only difficulties permitted by `maximumDifficultyLevel`, the three protocol steps, remaining times, auto-confirm and cancel controls. Both receive callbacks and primitive state only.

- [ ] **Step 6: Reduce `OperationPanel` to a provider host**

```dart
class OperationPanel extends ConsumerWidget {
  const OperationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotId = ref.watch(selectedRobotIdProvider);
    final state = ref.watch(operationPanelControllerProvider);
    final controller = ref.read(operationPanelControllerProvider.notifier);
    // Dispatch to EngineerOperationSection or CombatOperationSection.
  }
}
```

Use `ref.listen` on the structured feedback serial to show success/error feedback exactly once.

- [ ] **Step 7: Run widget tests and analysis**

Run: `flutter test test/operation_panel_test.dart --reporter expanded`

Expected: PASS with no respawn control, telemetry-driven availability, pulse and TechCore rendering.

Run: `flutter analyze`

Expected: `No issues found!`

- [ ] **Step 8: Mark Phase 3 complete and commit**

```powershell
git add -- lib/features/dashboard/presentation/operation_panel_strings.dart lib/features/dashboard/presentation/widgets/operation_panel.dart lib/features/dashboard/presentation/widgets/operation_panel_sections.dart test/operation_panel_test.dart feature_spec.md
git commit -m "feat: connect operation panel to live status"
```

---

### Task 4: Regression, audit and feature_spec closeout

**Files:**
- Modify: `feature_spec.md`
- Modify only if failures require fixes: files from Tasks 1–3.

**Interfaces:**
- Consumes: all v0.1.4 deliverables.
- Produces: verified v0.1.4 implementation and final canonical documentation.

- [ ] **Step 1: Format implementation files**

Run:

```powershell
dart format lib/core/constants/protocol_constants.dart lib/features/dashboard/data/operation_command_service.dart lib/features/dashboard/domain/operation_panel_state.dart lib/features/dashboard/logic/operation_panel_controller.dart lib/features/dashboard/presentation/operation_panel_strings.dart lib/features/dashboard/presentation/widgets/operation_panel.dart lib/features/dashboard/presentation/widgets/operation_panel_sections.dart test/operation_command_service_test.dart test/operation_panel_controller_test.dart test/operation_panel_test.dart
```

Expected: formatter completes without syntax errors.

- [ ] **Step 2: Run focused regression**

Run:

```powershell
flutter test test/operation_command_service_test.dart test/operation_panel_controller_test.dart test/operation_panel_test.dart test/game_state_notifier_test.dart test/notification_runtime_test.dart --reporter expanded
```

Expected: all focused tests PASS. If the Flutter process again produces no output, terminate only that test process, record the environment failure, and do not report success.

- [ ] **Step 3: Run static analysis and full tests**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test --reporter expanded`

Expected: all tests PASS.

- [ ] **Step 4: Perform the AGENTS.md self-audit**

Check every item: function length, duplicate code, layer placement, naming, imports, null safety, constants, async errors, platform compatibility, public dartdoc, protocol downgrade and timer/resource cleanup.

- [ ] **Step 5: Close out feature_spec**

Mark all v0.1.4 Tasks `[x]`; replace “开发中” with the verified result; update the new-Agent summary, exact test count, Changelog row and document footer. Keep later versions as candidates.

- [ ] **Step 6: Final commit**

```powershell
git add -- feature_spec.md pubspec.yaml pubspec.lock
git commit -m "docs: complete v0.1.4 operation panel"
```

Do not create a release tag unless the user explicitly requests publication.
