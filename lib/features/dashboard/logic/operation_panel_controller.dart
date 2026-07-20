import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protobuf/protobuf.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/state/session_providers.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import '../../../services/mqtt_service.dart';
import '../data/operation_command_service.dart';
import '../domain/operation_panel_state.dart';
import 'stream_providers.dart';

const Duration _startExchangeRepeatInterval = Duration(milliseconds: 200);
const Duration _confirmAssemblyRepeatInterval = Duration(milliseconds: 300);

/// 可取消的操作指令定时发送任务。
abstract interface class OperationRepeater {
  /// 停止后续定时回调。
  void cancel();
}

/// 创建定时发送任务的可注入工厂。
typedef OperationRepeatFactory =
    OperationRepeater Function(Duration interval, void Function() callback);

class _TimerOperationRepeater implements OperationRepeater {
  _TimerOperationRepeater(Duration interval, void Function() callback)
    : _timer = Timer.periodic(interval, (_) => callback());

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

OperationRepeater _createOperationRepeater(
  Duration interval,
  void Function() callback,
) {
  return _TimerOperationRepeater(interval, callback);
}

/// 处理协议状态并管理操作指令生命周期。
class OperationPanelController extends StateNotifier<OperationPanelState> {
  /// 创建操作面板控制器。
  OperationPanelController({
    required OperationCommandService commands,
    required OperationRepeatFactory repeatFactory,
    required bool connected,
    required int robotId,
  }) : this._(commands, repeatFactory, connected: connected, robotId: robotId);

  OperationPanelController._(
    this._commands,
    this._repeatFactory, {
    required this._connected,
    required int robotId,
  }) : super(OperationPanelState(role: operationRobotRoleForId(robotId)));

  final OperationCommandService _commands;
  final OperationRepeatFactory _repeatFactory;
  bool _connected;
  bool _disposed = false;
  int _feedbackSerial = 0;
  OperationRepeater? _startRepeater;
  OperationRepeater? _confirmRepeater;

  /// 接收当前身份对应的机器人动态或科技核心消息。
  void handleMessage(GeneratedMessage message) {
    if (!_connected || _disposed) return;
    switch (message) {
      case final RobotDynamicStatus status:
        _applyDynamicStatus(status);
      case final TechCoreMotionStateSync status:
        _applyTechCoreStatus(status);
    }
  }

  /// 同步 MQTT 是否可发送指令；断开时清除失效状态并停止重发。
  void setConnected({required bool connected}) {
    if (_connected == connected || _disposed) return;
    _connected = connected;
    if (!connected) _clearIdentityState(state.role);
  }

  /// 切换身份时清除上一身份的协议状态和定时任务。
  void resetIdentity([int? robotId]) {
    if (_disposed) return;
    final role = robotId == null
        ? state.role
        : operationRobotRoleForId(robotId);
    _clearIdentityState(role);
  }

  /// 更新常规兑换的弹丸数量。
  void selectAmmoQuantity(int quantity) {
    if (quantity > 0) state = state.copyWith(ammoQuantity: quantity);
  }

  /// 按当前机器人职责发送 17mm 或 42mm 常规兑换请求。
  void exchangeAmmo() {
    if (!_connected) return;
    switch (state.role) {
      case OperationRobotRole.hero:
        _attempt(() => _commands.exchange42mm(state.ammoQuantity));
      case OperationRobotRole.infantry:
        _attempt(() => _commands.exchange17mm(state.ammoQuantity));
      case OperationRobotRole.engineer || OperationRobotRole.unsupported:
        return;
    }
  }

  /// 在裁判系统允许时发送远程回血请求。
  void remoteHeal() {
    if (_connected && state.remoteHealEnabled) _attempt(_commands.remoteHeal);
  }

  /// 在裁判系统允许时发送远程买弹请求。
  void remoteAmmo() {
    if (_connected && state.remoteAmmoEnabled) _attempt(_commands.remoteAmmo);
  }

  /// 开始或停止指定难度的工程兑换请求重发。
  void toggleExchange(int difficulty) {
    if (!_canStartExchange(difficulty)) return;
    if (state.activeDifficulty == difficulty) {
      _cancelStartRepeat();
      state = state.copyWith(activeDifficulty: null);
      _emitFeedback(OperationFeedbackType.stopped);
      return;
    }
    _cancelStartRepeat();
    if (!_attempt(() => _commands.startExchange(difficulty))) return;
    state = state.copyWith(activeDifficulty: difficulty);
    _startRepeater = _repeatFactory(
      _startExchangeRepeatInterval,
      () => _repeatStartExchange(difficulty),
    );
  }

  /// 开启或停止进入工程流程后的自动确认装配。
  void toggleAutoConfirm() {
    if (!_connected) return;
    if (state.autoConfirmArmed) {
      _stopConfirmRepeat(clearArm: true);
      _emitFeedback(OperationFeedbackType.stopped);
      return;
    }
    state = state.copyWith(autoConfirmArmed: true);
    _emitFeedback(OperationFeedbackType.autoConfirmArmed);
    _ensureConfirmRepeat();
  }

  /// 发送取消装配并立即停止所有工程指令重发。
  void cancelAssembly() {
    if (_connected) _attempt(_commands.cancelAssembly);
    _stopWorkflowRepeats();
  }

  void _applyDynamicStatus(RobotDynamicStatus status) {
    final hasBaseline = state.telemetryKnown;
    final healPulse = _nextPulse(
      hasBaseline,
      state.remoteHealEnabled,
      status.canRemoteHeal,
      state.remoteHealPulseToken,
    );
    final ammoPulse = _nextPulse(
      hasBaseline,
      state.remoteAmmoEnabled,
      status.canRemoteAmmo,
      state.remoteAmmoPulseToken,
    );
    state = state.copyWith(
      telemetryKnown: true,
      remoteHealEnabled: status.canRemoteHeal,
      remoteAmmoEnabled: status.canRemoteAmmo,
      remoteHealPulseToken: healPulse,
      remoteAmmoPulseToken: ammoPulse,
    );
  }

  int _nextPulse(bool known, bool previous, bool next, int token) {
    return known && !previous && next ? token + 1 : token;
  }

  void _applyTechCoreStatus(TechCoreMotionStateSync status) {
    final wasFlowActive = state.techCoreKnown && state.techCore.isFlowActive;
    final next = _toPanelState(status);
    state = state.copyWith(techCoreKnown: true, techCore: next);
    if (_flowEndedOrReset(wasFlowActive, next)) {
      _stopWorkflowRepeats();
      return;
    }
    if (next.basicState != techCoreBasicStateInitial) {
      _cancelStartRepeat();
      state = state.copyWith(activeDifficulty: null);
    }
    _ensureConfirmRepeat();
  }

  TechCorePanelState _toPanelState(TechCoreMotionStateSync status) {
    return TechCorePanelState(
      maximumDifficulty: math.min(
        math.max(status.maximumDifficultyLevel, 0),
        maximumTechCoreDifficulty,
      ),
      basicState: status.basicState,
      putinDone: status.putinState == techCoreStepCompleted,
      moveDone: status.moveState == techCoreStepCompleted,
      rotateDone: status.rotateState == techCoreStepCompleted,
      remainingTotalSeconds: math.max(status.remainTimeAll, 0),
      remainingStepSeconds: math.max(status.remainTimeStep, 0),
    );
  }

  bool _flowEndedOrReset(bool wasFlowActive, TechCorePanelState next) {
    final resetToInitial =
        wasFlowActive && next.basicState == techCoreBasicStateInitial;
    final ranOutOfTime = wasFlowActive && next.remainingTotalSeconds == 0;
    return resetToInitial || ranOutOfTime || next.isCompleted;
  }

  bool _canStartExchange(int difficulty) {
    return _connected &&
        state.techCoreKnown &&
        state.techCore.basicState == techCoreBasicStateInitial &&
        difficulty >= 1 &&
        difficulty <= state.techCore.maximumDifficulty;
  }

  void _repeatStartExchange(int difficulty) {
    final shouldContinue =
        _connected &&
        state.activeDifficulty == difficulty &&
        state.techCore.basicState == techCoreBasicStateInitial;
    if (!shouldContinue) {
      _cancelStartRepeat();
      return;
    }
    if (!_attempt(() => _commands.startExchange(difficulty), notify: false)) {
      _cancelStartRepeat();
      state = state.copyWith(activeDifficulty: null);
    }
  }

  void _ensureConfirmRepeat() {
    if (_confirmRepeater != null || !_canConfirm()) return;
    if (!_attempt(_commands.confirmAssembly, notify: false)) {
      state = state.copyWith(autoConfirmArmed: false);
      return;
    }
    _confirmRepeater = _repeatFactory(
      _confirmAssemblyRepeatInterval,
      _repeatConfirmAssembly,
    );
  }

  bool _canConfirm() {
    return _connected &&
        state.autoConfirmArmed &&
        state.techCoreKnown &&
        state.techCore.isFlowActive &&
        state.techCore.remainingTotalSeconds > 0;
  }

  void _repeatConfirmAssembly() {
    if (!_canConfirm()) {
      _stopConfirmRepeat(clearArm: true);
      return;
    }
    if (!_attempt(_commands.confirmAssembly, notify: false)) {
      _stopConfirmRepeat(clearArm: true);
    }
  }

  bool _attempt(void Function() command, {bool notify = true}) {
    try {
      command();
      if (notify) _emitFeedback(OperationFeedbackType.commandSent);
      return true;
    } on Object catch (error) {
      _emitFeedback(OperationFeedbackType.failed, error);
      return false;
    }
  }

  void _emitFeedback(OperationFeedbackType type, [Object? error]) {
    _feedbackSerial++;
    state = state.copyWith(
      feedback: OperationFeedback(_feedbackSerial, type, error),
    );
  }

  void _clearIdentityState(OperationRobotRole role) {
    _cancelStartRepeat();
    _cancelConfirmRepeat();
    state = OperationPanelState(role: role, ammoQuantity: state.ammoQuantity);
  }

  void _stopWorkflowRepeats() {
    _cancelStartRepeat();
    _cancelConfirmRepeat();
    state = state.copyWith(activeDifficulty: null, autoConfirmArmed: false);
  }

  void _stopConfirmRepeat({required bool clearArm}) {
    _cancelConfirmRepeat();
    if (clearArm) state = state.copyWith(autoConfirmArmed: false);
  }

  void _cancelStartRepeat() {
    _startRepeater?.cancel();
    _startRepeater = null;
  }

  void _cancelConfirmRepeat() {
    _confirmRepeater?.cancel();
    _confirmRepeater = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelStartRepeat();
    _cancelConfirmRepeat();
    super.dispose();
  }
}

/// 提供通过 MQTT 发布操作指令的数据层服务。
final operationCommandServiceProvider = Provider<OperationCommandService>((
  ref,
) {
  final mqtt = ref.watch(mqttServiceProvider);
  return OperationCommandService(publish: mqtt.publish);
});

/// 当前身份对应的操作面板状态与控制器。
final operationPanelControllerProvider =
    StateNotifierProvider.autoDispose<
      OperationPanelController,
      OperationPanelState
    >((ref) {
      final controller = OperationPanelController(
        commands: ref.watch(operationCommandServiceProvider),
        repeatFactory: _createOperationRepeater,
        connected:
            ref.read(mqttConnectionStateSyncProvider) ==
            MqttConnectionState.connected,
        robotId: ref.read(selectedRobotIdProvider),
      );
      ref
        ..listen(mqttMessageProvider, (_, next) {
          next.whenData((envelope) {
            final message = envelope.protobufMessage;
            if (message != null) controller.handleMessage(message);
          });
        })
        ..listen(mqttConnectionStateSyncProvider, (_, next) {
          controller.setConnected(
            connected: next == MqttConnectionState.connected,
          );
        })
        ..listen(selectedRobotIdProvider, (_, next) {
          controller.resetIdentity(next);
        });
      return controller;
    });
