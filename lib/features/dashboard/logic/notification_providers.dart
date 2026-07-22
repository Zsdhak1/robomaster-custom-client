/// 通知规则引擎、部署跳转和连接质量监控的 Riverpod 接入。
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/navigation/app_navigation_rail.dart';
import '../../../core/protobuf/protobuf_parser.dart';
import '../../../core/state/session_providers.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import '../../../services/mqtt_service.dart';
import '../../custom_video/logic/custom_video_providers.dart';
import '../../settings/domain/combat_notification_rules.dart';
import '../../settings/domain/notification_preferences.dart';
import '../../settings/domain/notification_rule_profile.dart';
import '../../settings/logic/kill_estimate_provider.dart';
import '../../settings/logic/notification_profile_provider.dart';
import 'combat_buff_tracker.dart';
import 'connection_quality_evaluator.dart';
import 'dashboard_notification_controller.dart';
import 'dashboard_notification_models.dart';
import 'deployment_navigation_controller.dart';
import 'module_status_monitor.dart';
import 'mqtt_notification_tracker.dart';
import 'notification_rule_engine.dart';
import 'stream_providers.dart';

const Duration _qualitySampleInterval = Duration(milliseconds: 500);
const int _robotHealthCount = 5;
const int _heroBaseId = 1;

/// 英雄部署自动跳转的倒计时控制器。
final deploymentNavigationProvider =
    StateNotifierProvider<
      DeploymentNavigationController,
      DeploymentNavigationState
    >((ref) {
      var startedByCountdown = false;
      return DeploymentNavigationController(
        () async {
          if (ref.read(customVideoControllerProvider)) return false;
          await ref.read(customVideoControllerProvider.notifier).start();
          startedByCountdown = true;
          return true;
        },
        () {
          if (!startedByCountdown) return;
          ref.read(customVideoControllerProvider.notifier).stop();
          startedByCountdown = false;
        },
        () {
          startedByCountdown = false;
          ref.read(appDestinationProvider.notifier).state =
              AppDestination.customVideo;
        },
      );
    });

/// 真实协议和运行状态驱动的全局通知队列。
final dashboardNotificationProvider =
    StateNotifierProvider<
      DashboardNotificationController,
      DashboardNotificationState
    >((ref) {
      final controller = DashboardNotificationController();
      final runtime = _NotificationRuntime(
        ref,
        controller,
        ref.read(moduleStatusMonitorProvider.notifier),
      )..start();
      ref.onDispose(runtime.dispose);
      return controller;
    });

class _NotificationRuntime {
  _NotificationRuntime(this.ref, this.controller, this.moduleMonitor);

  final Ref ref;
  final DashboardNotificationController controller;
  final ModuleStatusMonitorController moduleMonitor;
  final NotificationRuleEngine _engine = NotificationRuleEngine();
  final ConnectionQualityEvaluator _quality = ConnectionQualityEvaluator();
  final MqttNotificationTracker _mqttTracker = MqttNotificationTracker();
  final UdpWindowSampler _udpSampler = UdpWindowSampler();
  Timer? _qualityTimer;
  StreamSubscription<ProtobufEnvelope>? _mqttEnvelopeSubscription;
  MqttConnectionState? _mqttState;
  DateTime? _mqttConnectedAt;
  int? _mqttGeneration;
  DateTime? _lastMqttMessageAt;
  CustomVideoStats? _customStats;
  GameStatus? _gameStatus;
  int? _selectedRobotId;

  void start() {
    _selectedRobotId = ref.read(selectedRobotIdProvider);
    final initialMqttState =
        ref.read(mqttConnectionStateProvider).valueOrNull ??
        ref.read(mqttServiceProvider).state;
    final now = DateTime.now();
    _mqttState = initialMqttState;
    _mqttTracker.handle(initialMqttState, now);
    if (initialMqttState == MqttConnectionState.connected) {
      _mqttConnectedAt = now;
      _mqttGeneration = ref.read(mqttServiceProvider).connectionGeneration;
    }
    _mqttEnvelopeSubscription = ref
        .read(mqttEnvelopeStreamFactoryProvider)()
        .listen(_handleEnvelope);
    ref
      ..listen(mqttConnectionStateProvider, (_, next) {
        next.whenData(_handleMqttState);
      })
      ..listen(customVideoStatsProvider, (_, next) {
        next.whenData((stats) => _customStats = stats);
      })
      ..listen(selectedRobotIdProvider, (_, next) {
        final previous = _selectedRobotId;
        _selectedRobotId = next;
        if (shouldResetNotificationMatchForIdentity(previous, next)) {
          _resetMatchState();
        }
      });
    _qualityTimer = Timer.periodic(
      _qualitySampleInterval,
      (_) => _sampleQuality(),
    );
  }

  void _handleMqttState(MqttConnectionState next) {
    final previous = _mqttState;
    _mqttState = next;
    final now = DateTime.now();
    if (next == MqttConnectionState.connected &&
        previous != MqttConnectionState.connected) {
      _mqttConnectedAt = now;
      _mqttGeneration = ref.read(mqttServiceProvider).connectionGeneration;
    }
    if (shouldResetNotificationMatchForMqttTransition(previous, next)) {
      _gameStatus = null;
      _mqttConnectedAt = null;
      _mqttGeneration = null;
      _lastMqttMessageAt = null;
      _resetMqttSessionState();
    }
    _emitNullable(_mqttTracker.handle(next, now));
  }

  void _handleEnvelope(ProtobufEnvelope envelope) {
    final accept = shouldAcceptNotificationEnvelope(
      mqttState: _mqttState,
      connectedGeneration: _mqttGeneration,
      envelopeGeneration: envelope.connectionGeneration,
    );
    if (accept == false) return;
    _lastMqttMessageAt = envelope.timestamp;
    final message = envelope.protobufMessage;
    switch (message) {
      case final GameStatus status:
        _handleGameStatus(status);
      case final GlobalUnitStatus status:
        _handleUnitStatus(status, envelope.timestamp);
      case final Event event:
        _emitNullable(
          _engine.handleProtocolEvent(
            eventId: event.eventId,
            param: event.param,
            timestamp: envelope.timestamp,
          ),
        );
      case final DeployModeStatusSync status:
        _handleDeployStatus(status, envelope.timestamp);
      case final RobotModuleStatus status:
        for (final event in moduleStatusEventsFromReading(
          monitor: moduleMonitor,
          engine: _engine,
          status: status,
          timestamp: envelope.timestamp,
        )) {
          _emit(event);
        }
      case final Buff buff:
        observeBuffFromProtocol(
          engine: _engine,
          buff: buff,
          timestamp: envelope.timestamp,
        );
    }
  }

  void _handleGameStatus(GameStatus status) {
    final previous = _gameStatus;
    _gameStatus = status;
    if (!shouldResetNotificationMatch(previous, status)) return;
    _resetMatchState();
  }

  void _resetMatchState() {
    resetNotificationMatchState(engine: _engine);
    controller.resetRuntimeState();
    _quality.reset();
    _udpSampler.reset();
    ref.read(deploymentNavigationProvider.notifier).resetMatch();
  }

  void _resetMqttSessionState() {
    _resetMatchState();
    moduleMonitor.reset();
  }

  void _handleUnitStatus(GlobalUnitStatus status, DateTime timestamp) {
    if (_gameStatus?.currentStage != stageInMatch) return;
    final health = status.robotHealth;
    if (health.length < _robotHealthCount * 2) return;
    final sample = UnitHealthSample(
      allyHealth: health.take(_robotHealthCount).toList(growable: false),
      enemyHealth: health
          .skip(_robotHealthCount)
          .take(_robotHealthCount)
          .toList(growable: false),
      selectedRobotId: ref.read(selectedRobotIdProvider),
      timestamp: timestamp,
      remainingMatchSeconds: remainingMatchSecondsFromProtocol(_gameStatus),
      enemyBaseHealth: enemyBaseHealthFromProtocol(status),
      combatBuffs: _engine.combatBuffsAt(timestamp),
    );
    final profile = ref.read(activeNotificationProfileProvider);
    final events = _engine.handleUnitHealth(
      sample,
      killLine: profile.killLine,
      respawn: profile.respawn,
      estimate: ref.read(killEstimateConfigProvider),
    );
    for (final event in events) {
      _emit(event);
    }
  }

  void _handleDeployStatus(DeployModeStatusSync status, DateTime timestamp) {
    if (!_engine.observeDeployStatus(status.status)) return;
    final selectedId = ref.read(selectedRobotIdProvider);
    if (selectedId % 100 != _heroBaseId) return;
    final config = ref
        .read(activeNotificationProfileProvider)
        .deploymentNavigation;
    final started = ref
        .read(deploymentNavigationProvider.notifier)
        .start(config);
    if (!started) return;
    _emit(
      RuleNotificationEvent(
        type: NotificationEventType.heroDeployAutoNavigation,
        headline: '即将进入自定义图传',
        detail: '${config.countdownSeconds} 秒倒计时已开始，可取消或立即进入',
        dedupKey: 'hero-deploy-navigation',
        occurredAt: timestamp,
      ),
    );
  }

  void _sampleQuality() {
    final now = DateTime.now();
    final video = ref.read(videoStreamServiceProvider);
    final loss = _udpSampler.sample(
      now: now,
      received: video.packetsReceived,
      dropped: video.packetsDropped,
      windowSeconds: ref
          .read(activeNotificationProfileProvider)
          .connectionQuality
          .udpWindowSeconds,
    );
    final metrics = _qualityMetrics(now, video.isListening, loss);
    final profile = ref.read(activeNotificationProfileProvider);
    final event = _quality.evaluate(
      metrics,
      _sensitivityAdjustedQualityConfig(profile),
    );
    _emitNullable(event);
  }

  ConnectionQualityMetrics _qualityMetrics(
    DateTime now,
    bool udpActive,
    double? udpLoss,
  ) {
    final mqttReference = _freshestMqttReference();
    final stats = _customStats;
    return ConnectionQualityMetrics(
      timestamp: now,
      mqttConnected: _mqttState == MqttConnectionState.connected,
      millisSinceLastMqttMessage: mqttReference == null
          ? null
          : now.difference(mqttReference).inMilliseconds,
      udpActive: udpActive,
      udpLossPercent: udpLoss,
      customVideoRunning: stats?.running ?? false,
      millisSinceLastCustomChunk: stats?.millisSinceLastChunk,
      decoderClients: stats?.decoderClients ?? 0,
      millisSinceLastKeyframe: stats?.millisSinceLastKeyframe,
    );
  }

  DateTime? _freshestMqttReference() {
    final messageAt = _lastMqttMessageAt;
    final connectedAt = _mqttConnectedAt;
    if (messageAt == null) return connectedAt;
    if (connectedAt == null) return messageAt;
    return messageAt.isAfter(connectedAt) ? messageAt : connectedAt;
  }

  void _emitNullable(RuleNotificationEvent? event) {
    if (event != null) _emit(event);
  }

  void _emit(RuleNotificationEvent event) {
    final profile = ref.read(activeNotificationProfileProvider);
    final paused = _gameStatus?.isPaused ?? false;
    final item = controller.showConfigured(event, profile, gamePaused: paused);
    if (item == null) return;
    final setting = profile.eventSettings[event.type];
    if (setting != null) {
      unawaited(playNotificationFeedback(profile.display, setting));
    }
  }

  void dispose() {
    _qualityTimer?.cancel();
    final subscription = _mqttEnvelopeSubscription;
    _mqttEnvelopeSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }
}

ConnectionQualityRuleConfig _sensitivityAdjustedQualityConfig(
  NotificationRuleProfile profile,
) {
  final config = profile.connectionQuality;
  final sensitivity = profile.display.sensitivity;
  final factor = switch (sensitivity) {
    NotificationSensitivity.conservative => 1.5,
    NotificationSensitivity.standard => 1.0,
    NotificationSensitivity.sensitive => 0.5,
  };
  return config.copyWith(
    debounceMilliseconds: (config.debounceMilliseconds * factor).round(),
    recoveryStableSeconds: (config.recoveryStableSeconds * factor)
        .round()
        .clamp(1, 60),
  );
}

/// 将 Protobuf 模块字段映射为只包含已知、明确携带状态的读数。
ModuleStatusReading moduleStatusReadingFromProtocol(RobotModuleStatus status) {
  return ModuleStatusReading.fromProtocolValues({
    for (final field in _moduleProtocolFields(status))
      if (field.present && knownModuleStatusValues.contains(field.value))
        field.type: field.value,
  });
}

typedef _ModuleProtocolField = ({
  RobotModuleType type,
  bool present,
  int value,
});

List<_ModuleProtocolField> _moduleProtocolFields(RobotModuleStatus status) {
  return [..._powerModuleFields(status), ..._controlModuleFields(status)];
}

List<_ModuleProtocolField> _powerModuleFields(RobotModuleStatus status) {
  return [
    (
      type: RobotModuleType.powerManager,
      present: status.hasPowerManager(),
      value: status.powerManager,
    ),
    (type: RobotModuleType.rfid, present: status.hasRfid(), value: status.rfid),
    (
      type: RobotModuleType.lightStrip,
      present: status.hasLightStrip(),
      value: status.lightStrip,
    ),
    (
      type: RobotModuleType.smallShooter,
      present: status.hasSmallShooter(),
      value: status.smallShooter,
    ),
    (
      type: RobotModuleType.bigShooter,
      present: status.hasBigShooter(),
      value: status.bigShooter,
    ),
    (type: RobotModuleType.uwb, present: status.hasUwb(), value: status.uwb),
  ];
}

List<_ModuleProtocolField> _controlModuleFields(RobotModuleStatus status) {
  return [
    (
      type: RobotModuleType.armor,
      present: status.hasArmor(),
      value: status.armor,
    ),
    (
      type: RobotModuleType.videoTransmission,
      present: status.hasVideoTransmission(),
      value: status.videoTransmission,
    ),
    (
      type: RobotModuleType.capacitor,
      present: status.hasCapacitor(),
      value: status.capacitor,
    ),
    (
      type: RobotModuleType.mainController,
      present: status.hasMainController(),
      value: status.mainController,
    ),
    (
      type: RobotModuleType.laserDetectionModule,
      present: status.hasLaserDetectionModule(),
      value: status.laserDetectionModule,
    ),
  ];
}

/// 使用调用方注入的监控器处理模块读数并映射通知事件。
List<RuleNotificationEvent> moduleStatusEventsFromReading({
  required ModuleStatusMonitorController monitor,
  required NotificationRuleEngine engine,
  required RobotModuleStatus status,
  required DateTime timestamp,
}) {
  return monitor
      .observe(moduleStatusReadingFromProtocol(status))
      .map((transition) => engine.moduleEvent(transition, timestamp))
      .toList(growable: false);
}

/// 将 Buff 协议字段连同信封时间写入规则引擎。
bool observeBuffFromProtocol({
  required NotificationRuleEngine engine,
  required Buff buff,
  required DateTime timestamp,
}) {
  final complete =
      buff.hasRobotId() &&
      buff.hasBuffType() &&
      buff.hasBuffLevel() &&
      buff.hasBuffLeftTime();
  if (!complete) return false;
  engine.observeBuff(
    CombatBuffSample(
      robotId: buff.robotId,
      buffType: buff.buffType,
      level: buff.buffLevel,
      leftSeconds: buff.buffLeftTime,
      receivedAt: timestamp,
    ),
  );
  return true;
}

/// 判定比赛状态变化是否必须清理比赛级通知状态。
bool shouldResetNotificationMatch(GameStatus? previous, GameStatus current) {
  if (previous == null) return false;
  return previous.currentRound != current.currentRound ||
      (previous.currentStage == stageInMatch &&
          current.currentStage != stageInMatch);
}

/// 判定 MQTT 从已连接状态离开时是否必须清理比赛级通知状态。
bool shouldResetNotificationMatchForMqttTransition(
  MqttConnectionState? previous,
  MqttConnectionState current,
) {
  return previous == MqttConnectionState.connected &&
      current != MqttConnectionState.connected;
}

/// 判定操作身份变化是否必须清理比赛级通知状态。
bool shouldResetNotificationMatchForIdentity(int? previous, int current) {
  return previous != null && previous != current;
}

/// 仅返回协议中明确出现的比赛剩余秒数。
int? remainingMatchSecondsFromProtocol(GameStatus? status) {
  if (status == null) return null;
  return status.hasStageCountdownSec() ? status.stageCountdownSec : null;
}

/// 仅返回协议中明确出现的敌方基地血量。
int? enemyBaseHealthFromProtocol(GlobalUnitStatus status) {
  return status.hasEnemyBaseHealth() ? status.enemyBaseHealth : null;
}

/// 判断信封是否属于当前已连接的 MQTT 会话。
bool shouldAcceptNotificationEnvelope({
  required MqttConnectionState? mqttState,
  required int? connectedGeneration,
  required int envelopeGeneration,
}) {
  if (mqttState != MqttConnectionState.connected ||
      connectedGeneration == null) {
    return false;
  }
  return envelopeGeneration == connectedGeneration;
}

/// 清理规则引擎持有的比赛级状态。
void resetNotificationMatchState({required NotificationRuleEngine engine}) {
  engine.resetMatch();
}

/// 按当前通知偏好播放系统声音和 Android 震动，失败时静默降级。
Future<void> playNotificationFeedback(
  NotificationDisplayConfig display,
  NotificationEventSetting setting,
) async {
  try {
    if (display.soundEnabled && setting.playSound) {
      await SystemSound.play(SystemSoundType.alert);
    }
    if (Platform.isAndroid && display.vibrationEnabled) {
      await HapticFeedback.vibrate();
    }
  } on Object {
    // 系统反馈能力不可用时静默降级，不影响通知本身。
  }
}

/// 使用累计 UDP 计数计算滑动窗口丢包率。
class UdpWindowSampler {
  final Queue<_UdpSample> _samples = Queue<_UdpSample>();

  /// 清空当前比赛的采样基线。
  void reset() => _samples.clear();

  /// 记录累计计数，并在至少存在两个样本时返回窗口丢包百分比。
  double? sample({
    required DateTime now,
    required int received,
    required int dropped,
    required int windowSeconds,
  }) {
    _samples.add(_UdpSample(now, received, dropped));
    final cutoff = now.subtract(Duration(seconds: windowSeconds));
    while (_samples.length > 1 &&
        _samples.elementAt(1).timestamp.isBefore(cutoff)) {
      _samples.removeFirst();
    }
    if (_samples.length < 2) return null;
    final first = _samples.first;
    final receivedDelta = received - first.received;
    final droppedDelta = dropped - first.dropped;
    if (receivedDelta < 0 || droppedDelta < 0) {
      _samples.clear();
      return null;
    }
    final total = receivedDelta + droppedDelta;
    return total <= 0 ? null : droppedDelta * 100 / total;
  }
}

class _UdpSample {
  const _UdpSample(this.timestamp, this.received, this.dropped);

  final DateTime timestamp;
  final int received;
  final int dropped;
}
