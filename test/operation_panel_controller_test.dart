import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/features/dashboard/data/operation_command_service.dart';
import 'package:robomaster_custom_client_1/features/dashboard/domain/operation_panel_state.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/operation_panel_controller.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';

typedef _PublishedMessage = ({String topic, GeneratedMessage message});

void main() {
  group('dynamic operation availability', _dynamicAvailabilityTests);
  group('identity lifecycle', _identityLifecycleTests);
  group('combat operations', _combatOperationTests);
  group('tech core conversion', _techCoreConversionTests);
  group('tech core repeats', _techCoreRepeatTests);
  group('protocol repeat lifecycle', _protocolRepeatLifecycleTests);
  group('external repeat lifecycle', _externalRepeatLifecycleTests);
}

void _dynamicAvailabilityTests() {
  test('first telemetry snapshot establishes baseline without pulse', () {
    final harness = _buildHarness();

    harness.controller.handleMessage(
      RobotDynamicStatus(canRemoteHeal: true, canRemoteAmmo: true),
    );

    expect(harness.controller.state.remoteHealEnabled, isTrue);
    expect(harness.controller.state.remoteAmmoEnabled, isTrue);
    expect(harness.controller.state.remoteHealPulseToken, 0);
    expect(harness.controller.state.remoteAmmoPulseToken, 0);
  });

  test('false to true increments only the matching pulse token', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..handleMessage(RobotDynamicStatus())
      ..handleMessage(RobotDynamicStatus(canRemoteHeal: true));
    expect(controller.state.remoteHealPulseToken, 1);
    expect(controller.state.remoteAmmoPulseToken, 0);

    controller.handleMessage(
      RobotDynamicStatus(canRemoteHeal: true, canRemoteAmmo: true),
    );
    expect(controller.state.remoteHealPulseToken, 1);
    expect(controller.state.remoteAmmoPulseToken, 1);
  });
}

void _identityLifecycleTests() {
  test('identity reset clears identity-scoped telemetry and timers', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..handleMessage(RobotDynamicStatus(canRemoteHeal: true))
      ..handleMessage(_initialCore())
      ..toggleExchange(2)
      ..toggleAutoConfirm()
      ..resetIdentity(2);

    expect(controller.state.role, OperationRobotRole.engineer);
    expect(controller.state.telemetryKnown, isFalse);
    expect(controller.state.techCoreKnown, isFalse);
    expect(controller.state.activeDifficulty, isNull);
    expect(controller.state.autoConfirmArmed, isFalse);
    expect(harness.repeaters.every((repeater) => repeater.isCancelled), isTrue);
  });
}

void _combatOperationTests() {
  test('combat command follows role and selected quantity', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..selectAmmoQuantity(30)
      ..exchangeAmmo()
      ..resetIdentity(3)
      ..exchangeAmmo();

    final commands = _commonMessages(harness.published);
    expect(commands[0].cmdType, commonCommandExchange42mm);
    expect(commands[0].param, 30);
    expect(commands[1].cmdType, commonCommandExchange17mm);
    expect(commands[1].param, 30);
    expect(controller.state.role, OperationRobotRole.infantry);
  });

  test('remote commands publish only while protocol allows them', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..handleMessage(RobotDynamicStatus())
      ..remoteHeal()
      ..remoteAmmo()
      ..handleMessage(RobotDynamicStatus(canRemoteHeal: true))
      ..remoteHeal()
      ..remoteAmmo()
      ..handleMessage(
        RobotDynamicStatus(canRemoteHeal: true, canRemoteAmmo: true),
      )
      ..remoteAmmo();

    final commands = _commonMessages(harness.published);
    expect(commands, hasLength(2));
    expect(commands[0].cmdType, commonCommandRemoteHeal);
    expect(commands[1].cmdType, commonCommandRemoteAmmo);
    expect(commands[1].param, remoteAmmoExchangeRounds);
    expect(controller.state.remoteAmmoEnabled, isTrue);
  });
}

void _techCoreConversionTests() {
  test('tech core fields are normalized into immutable primitives', () {
    final harness = _buildHarness();

    harness.controller.handleMessage(
      TechCoreMotionStateSync(
        maximumDifficultyLevel: 99,
        basicState: 2,
        putinState: 2,
        moveState: 1,
        rotateState: 99,
        remainTimeAll: 18,
        remainTimeStep: 4,
      ),
    );

    final core = harness.controller.state.techCore;
    expect(core.maximumDifficulty, 4);
    expect(core.basicState, 2);
    expect(core.putinDone, isFalse);
    expect(core.moveDone, isTrue);
    expect(core.rotateDone, isFalse);
    expect(core.remainingTotalSeconds, 18);
    expect(core.remainingStepSeconds, 4);
  });
}

void _techCoreRepeatTests() {
  test('motion state stops start-exchange repeat', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..handleMessage(_initialCore())
      ..toggleExchange(3);
    final startRepeater = harness.repeaters.single..tick();
    expect(_assemblyMessages(harness.published), hasLength(2));
    controller.handleMessage(_activeCore());

    expect(startRepeater.isCancelled, isTrue);
    expect(controller.state.activeDifficulty, isNull);
  });

  test('tech core completion stops confirmation repeat', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..toggleAutoConfirm()
      ..handleMessage(_activeCore());
    final confirmRepeater = harness.repeaters.single;

    controller.handleMessage(_completedCore());

    expect(confirmRepeater.isCancelled, isTrue);
    expect(controller.state.autoConfirmArmed, isFalse);
  });
}

void _protocolRepeatLifecycleTests() {
  test('active to initial reset stops all repeats', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..handleMessage(_initialCore())
      ..toggleExchange(2)
      ..handleMessage(_activeCore())
      ..toggleAutoConfirm()
      ..handleMessage(_initialCore());

    expect(harness.repeaters.every((repeater) => repeater.isCancelled), isTrue);
    expect(controller.state.activeDifficulty, isNull);
    expect(controller.state.autoConfirmArmed, isFalse);
  });

  test('zero remaining time stops confirmation after flow activation', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..toggleAutoConfirm()
      ..handleMessage(_activeCore());
    final confirmRepeater = harness.repeaters.single;

    controller.handleMessage(_activeCore(remainingSeconds: 0));

    expect(confirmRepeater.isCancelled, isTrue);
    expect(controller.state.autoConfirmArmed, isFalse);
  });
}

void _externalRepeatLifecycleTests() {
  test('disconnect stops all repeats', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..toggleAutoConfirm()
      ..handleMessage(_activeCore())
      ..setConnected(connected: false);

    expect(harness.repeaters.single.isCancelled, isTrue);
    expect(controller.state.telemetryKnown, isFalse);
    expect(controller.state.techCoreKnown, isFalse);
    expect(controller.state.autoConfirmArmed, isFalse);
  });

  test('cancel sends cancel and stops all repeats', () {
    final harness = _buildHarness();
    final controller = harness.controller
      ..toggleAutoConfirm()
      ..handleMessage(_activeCore())
      ..cancelAssembly();

    final last = _assemblyMessages(harness.published).last;
    expect(last.operation, assemblyOperationCancel);
    expect(harness.repeaters.single.isCancelled, isTrue);
    expect(controller.state.autoConfirmArmed, isFalse);
  });

  test('dispose cancels all repeaters', () {
    final harness = _buildHarness(registerTearDown: false);
    harness.controller
      ..handleMessage(_initialCore())
      ..toggleExchange(4)
      ..dispose();

    expect(harness.repeaters.single.isCancelled, isTrue);
  });
}

_ControllerHarness _buildHarness({bool registerTearDown = true}) {
  final published = <_PublishedMessage>[];
  final repeaters = <_ManualRepeater>[];
  final commands = OperationCommandService(
    publish: (topic, message) {
      published.add((topic: topic, message: message));
    },
  );
  final controller = OperationPanelController(
    commands: commands,
    repeatFactory: (interval, callback) {
      final repeater = _ManualRepeater(interval, callback);
      repeaters.add(repeater);
      return repeater;
    },
    connected: true,
    robotId: 1,
  );
  if (registerTearDown) addTearDown(controller.dispose);
  return (controller: controller, published: published, repeaters: repeaters);
}

typedef _ControllerHarness = ({
  OperationPanelController controller,
  List<_PublishedMessage> published,
  List<_ManualRepeater> repeaters,
});

class _ManualRepeater implements OperationRepeater {
  _ManualRepeater(this.interval, this._callback);

  final Duration interval;
  final void Function() _callback;
  bool isCancelled = false;

  void tick() {
    if (!isCancelled) _callback();
  }

  @override
  void cancel() => isCancelled = true;
}

TechCoreMotionStateSync _initialCore() {
  return TechCoreMotionStateSync(
    maximumDifficultyLevel: 4,
    basicState: 1,
    remainTimeAll: 20,
  );
}

TechCoreMotionStateSync _activeCore({int remainingSeconds = 20}) {
  return TechCoreMotionStateSync(
    maximumDifficultyLevel: 4,
    basicState: 2,
    remainTimeAll: remainingSeconds,
  );
}

TechCoreMotionStateSync _completedCore() {
  return TechCoreMotionStateSync(
    maximumDifficultyLevel: 4,
    basicState: 3,
    putinState: 1,
    moveState: 1,
    rotateState: 1,
  );
}

List<AssemblyCommand> _assemblyMessages(List<_PublishedMessage> published) {
  return published
      .where((entry) => entry.topic == topicAssemblyCommand)
      .map((entry) => entry.message as AssemblyCommand)
      .toList();
}

List<CommonCommand> _commonMessages(List<_PublishedMessage> published) {
  return published
      .where((entry) => entry.topic == topicCommonCommand)
      .map((entry) => entry.message as CommonCommand)
      .toList();
}
