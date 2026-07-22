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
  final _UdpWindowSampler _udpSampler = _UdpWindowSampler();
  Timer? _qualityTimer;
  MqttConnectionState? _mqttState;
  DateTime? _mqttConnectedAt;
  DateTime? _lastMqttMessageAt;
  CustomVideoStats? _customStats;
  GameStatus? _gameStatus;

  void start() {
    ref
      ..listen(mqttConnectionStateProvider, (_, next) {
        next.whenData(_handleMqttState);
      })
      ..listen(mqttMessageProvider, (_, next) {
        next.whenData(_handleEnvelope);
      })
      ..listen(customVideoStatsProvider, (_, next) {
        next.whenData((stats) => _customStats = stats);
      });
    _qualityTimer = Timer.periodic(
      _qualitySampleInterval,
      (_) => _sampleQuality(),
    );
  }

  void _handleMqttState(MqttConnectionState next) {
    if (next == MqttConnectionState.connecting) return;
    _mqttState = next;
    final now = DateTime.now();
    if (next == MqttConnectionState.connected) {
      _mqttConnectedAt = now;
    }
    _emitNullable(_mqttTracker.handle(next, now));
  }

  void _handleEnvelope(ProtobufEnvelope envelope) {
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
    }
  }

  void _handleGameStatus(GameStatus status) {
    final previous = _gameStatus;
    _gameStatus = status;
    final newRound =
        previous != null && previous.currentRound != status.currentRound;
    final returnedToPrematch =
        status.currentStage < 4 &&
        previous != null &&
        previous.currentStage >= 4;
    if (!newRound && !returnedToPrematch) return;
    _engine.resetMatch();
    moduleMonitor.reset();
    _quality.reset();
    ref.read(deploymentNavigationProvider.notifier).resetMatch();
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
      remainingMatchSeconds: _gameStatus?.stageCountdownSec,
      enemyBaseHealth: status.enemyBaseHealth,
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

ModuleStatusReading _moduleReading(RobotModuleStatus status) {
  final fields = <({RobotModuleType type, bool present, int value})>[
    _moduleField(
      RobotModuleType.powerManager,
      status.hasPowerManager(),
      status.powerManager,
    ),
    _moduleField(RobotModuleType.rfid, status.hasRfid(), status.rfid),
    _moduleField(
      RobotModuleType.lightStrip,
      status.hasLightStrip(),
      status.lightStrip,
    ),
    _moduleField(
      RobotModuleType.smallShooter,
      status.hasSmallShooter(),
      status.smallShooter,
    ),
    _moduleField(
      RobotModuleType.bigShooter,
      status.hasBigShooter(),
      status.bigShooter,
    ),
    _moduleField(RobotModuleType.uwb, status.hasUwb(), status.uwb),
    _moduleField(RobotModuleType.armor, status.hasArmor(), status.armor),
    _moduleField(
      RobotModuleType.videoTransmission,
      status.hasVideoTransmission(),
      status.videoTransmission,
    ),
    _moduleField(
      RobotModuleType.capacitor,
      status.hasCapacitor(),
      status.capacitor,
    ),
    _moduleField(
      RobotModuleType.mainController,
      status.hasMainController(),
      status.mainController,
    ),
    _moduleField(
      RobotModuleType.laserDetectionModule,
      status.hasLaserDetectionModule(),
      status.laserDetectionModule,
    ),
  ];
  return ModuleStatusReading.fromProtocolValues({
    for (final field in fields) if (field.present) field.type: field.value,
  });
}

({RobotModuleType type, bool present, int value}) _moduleField(
  RobotModuleType type,
  bool present,
  int value,
) => (type: type, present: present, value: value);

/// 使用调用方注入的监控器处理模块读数并映射通知事件。
List<RuleNotificationEvent> moduleStatusEventsFromReading({
  required ModuleStatusMonitorController monitor,
  required NotificationRuleEngine engine,
  required RobotModuleStatus status,
  required DateTime timestamp,
}) {
  return monitor
      .observe(_moduleReading(status))
      .map((transition) => engine.moduleEvent(transition, timestamp))
      .toList(growable: false);
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

class _UdpWindowSampler {
  final Queue<_UdpSample> _samples = Queue<_UdpSample>();

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
