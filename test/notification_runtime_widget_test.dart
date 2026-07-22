import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/core/navigation/app_shell.dart';
import 'package:robomaster_custom_client_1/core/protobuf/protobuf_parser.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_controller.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_models.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/deployment_navigation_controller.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/module_status_monitor.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_rule_engine.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/stream_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/module_status_panel.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:robomaster_custom_client_1/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  _testGlobalNotifications();
  _testDeploymentCountdown();
  _testRuntimeModulePanel();
  _testRuntimeMqttSession();
}

void _testRuntimeMqttSession() {
  test(
    'disconnect invalidates the old in-match status before reconnect',
    () async {
      final harness = await _RuntimeHarness.start();
      addTearDown(harness.dispose);
      expect(harness.connectionState, MqttConnectionState.connected);
      final firstSessionAt = DateTime.now().add(const Duration(seconds: 1));
      harness.addInMatchBaseline(firstSessionAt);
      await _flushEvents();

      await harness.setConnection(MqttConnectionState.disconnected);
      expect(
        harness.notificationState.visible.where(
          (item) => item.eventType == NotificationEventType.mqttDisconnected,
        ),
        hasLength(1),
      );
      await harness.setConnection(MqttConnectionState.connected);
      harness.addUnitStatus(1, DateTime.now().add(const Duration(seconds: 1)));
      await _flushEvents();

      expect(
        harness.notificationState.visible.where(
          (item) => item.eventType == NotificationEventType.enemyKillLine,
        ),
        isEmpty,
      );
    },
  );
}

class _RuntimeHarness {
  _RuntimeHarness(
    this.connectionStates,
    this.messages,
    this.container,
    this.connectionSubscription,
    this.runtimeSubscription,
  );

  static Future<_RuntimeHarness> start() async {
    final connections = StreamController<MqttConnectionState>.broadcast();
    final messages = StreamController<ProtobufEnvelope>.broadcast();
    final container = ProviderContainer(
      overrides: [
        mqttConnectionStateProvider.overrideWith((ref) => connections.stream),
        mqttMessageProvider.overrideWith((ref) => messages.stream),
        customVideoStatsProvider.overrideWith((ref) => const Stream.empty()),
        deploymentNavigationProvider.overrideWith(
          (ref) => _deploymentController(),
        ),
      ],
    );
    final connectionSubscription = container.listen(
      mqttConnectionStateProvider,
      (_, _) {},
      fireImmediately: true,
    );
    connections.add(MqttConnectionState.connected);
    await _flushEvents();
    final runtimeSubscription = container.listen(
      dashboardNotificationProvider,
      (_, _) {},
      fireImmediately: true,
    );
    return _RuntimeHarness(
      connections,
      messages,
      container,
      connectionSubscription,
      runtimeSubscription,
    );
  }

  final StreamController<MqttConnectionState> connectionStates;
  final StreamController<ProtobufEnvelope> messages;
  final ProviderContainer container;
  final ProviderSubscription<AsyncValue<MqttConnectionState>>
  connectionSubscription;
  final ProviderSubscription<DashboardNotificationState> runtimeSubscription;

  MqttConnectionState? get connectionState =>
      container.read(mqttConnectionStateProvider).valueOrNull;

  DashboardNotificationState get notificationState =>
      container.read(dashboardNotificationProvider);

  void addInMatchBaseline(DateTime timestamp) {
    messages
      ..add(
        _envelope(
          GameStatus(
            currentRound: 1,
            currentStage: stageInMatch,
            stageCountdownSec: 420,
          ),
          timestamp,
        ),
      )
      ..add(_envelope(_unitStatus(500), timestamp));
  }

  void addUnitStatus(int enemyHeroHealth, DateTime timestamp) {
    messages.add(_envelope(_unitStatus(enemyHeroHealth), timestamp));
  }

  Future<void> setConnection(MqttConnectionState state) async {
    connectionStates.add(state);
    await _flushEvents();
  }

  Future<void> dispose() async {
    connectionSubscription.close();
    runtimeSubscription.close();
    container.dispose();
    await connectionStates.close();
    await messages.close();
  }
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

GlobalUnitStatus _unitStatus(int enemyHeroHealth) {
  return GlobalUnitStatus(enemyBaseHealth: 5000)
    ..robotHealth.addAll([
      500,
      300,
      300,
      300,
      600,
      enemyHeroHealth,
      300,
      300,
      300,
      600,
    ]);
}

ProtobufEnvelope _envelope(Object message, DateTime timestamp) {
  return ProtobufEnvelope(
    topic: 'test',
    messageType: message.runtimeType.toString(),
    protobufMessage: message is GameStatus
        ? message
        : message as GlobalUnitStatus,
    rawBytes: Uint8List(0),
    timestamp: timestamp,
  );
}

void _testRuntimeModulePanel() {
  testWidgets('protocol module updates are visible in the shared panel', (
    tester,
  ) async {
    final monitor = ModuleStatusMonitorController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [moduleStatusMonitorProvider.overrideWith((ref) => monitor)],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 300, child: ModuleStatusPanel()),
          ),
        ),
      ),
    );

    moduleStatusEventsFromReading(
      monitor: monitor,
      engine: NotificationRuleEngine(),
      status: RobotModuleStatus(videoTransmission: 0),
      timestamp: DateTime(2026, 7, 22, 12),
    );
    await tester.pump();

    expect(find.text('模块状态'), findsOneWidget);
    expect(find.text('图传模块'), findsOneWidget);
  });
}

void _testGlobalNotifications() {
  testWidgets('AppShell renders global mixed-position notifications', (
    tester,
  ) async {
    final notifications = DashboardNotificationController();
    final deployment = _deploymentController();
    await _pumpShell(tester, notifications, deployment);

    notifications
      ..show(
        const DashboardNotificationContent(
          headline: 'INFO 测试',
          detail: '右上角通知',
          badge: 'INFO',
          icon: Icons.info_outline,
          accentColor: Colors.blue,
        ),
      )
      ..show(
        const DashboardNotificationContent(
          headline: 'CRITICAL 测试',
          detail: '顶部通知',
          badge: 'CRITICAL',
          icon: Icons.warning_rounded,
          accentColor: Colors.red,
          severity: NotificationSeverity.critical,
          style: DashboardNotificationStyle.topBanner,
          autoDismiss: false,
        ),
      );
    await tester.pump();

    expect(find.text('INFO 测试'), findsOneWidget);
    expect(find.text('CRITICAL 测试'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _testDeploymentCountdown() {
  testWidgets('deployment countdown is visible above AppShell content', (
    tester,
  ) async {
    final notifications = DashboardNotificationController();
    final deployment = _deploymentController();
    await _pumpShell(tester, notifications, deployment);

    deployment.start(
      const DeploymentNavigationConfig(
        countdownSeconds: 5,
        prestartVideo: false,
      ),
    );
    await tester.pump();

    expect(find.text('英雄已进入部署模式'), findsOneWidget);
    expect(find.text('立即进入'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

DeploymentNavigationController _deploymentController() {
  return DeploymentNavigationController(
    () async => false,
    () {},
    () {},
    const Duration(days: 1),
  );
}

Future<void> _pumpShell(
  WidgetTester tester,
  DashboardNotificationController notifications,
  DeploymentNavigationController deployment,
) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customVideoStatsProvider.overrideWith((ref) => const Stream.empty()),
        dashboardNotificationProvider.overrideWith((ref) => notifications),
        deploymentNavigationProvider.overrideWith((ref) => deployment),
      ],
      child: const MaterialApp(home: AppShell()),
    ),
  );
  await tester.pump();
  await tester.pump();
}
