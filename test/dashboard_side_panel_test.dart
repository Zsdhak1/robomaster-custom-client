/// 主仪表盘侧栏的模块状态切换测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/core/protobuf/protobuf_parser.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/game_state_notifier.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/module_status_monitor.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/stream_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/dashboard_side_panel.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_rule_profile.dart';
import 'package:robomaster_custom_client_1/features/settings/logic/notification_profile_provider.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';

void main() {
  testWidgets('switches to module panel until every module recovers', (
    tester,
  ) async {
    final controller = ModuleStatusMonitorController();
    await _pumpSidePanel(tester, controller: controller);

    expect(find.text('事件时间轴'), findsOneWidget);

    controller.observe(const ModuleStatusReading({
      RobotModuleType.videoTransmission: ModuleAvailability.offline,
      RobotModuleType.armor: ModuleAvailability.online,
    }));
    await tester.pumpAndSettle();

    expect(find.text('模块状态'), findsOneWidget);
    expect(find.text('图传模块'), findsOneWidget);
    expect(find.text('装甲模块'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('图传模块')).dy,
      lessThan(tester.getTopLeft(find.text('装甲模块')).dy),
    );

    controller.observe(const ModuleStatusReading({
      RobotModuleType.videoTransmission: ModuleAvailability.online,
    }));
    await tester.pumpAndSettle();

    expect(find.text('事件时间轴'), findsOneWidget);
  });

  testWidgets('shows module panel when offline notification is disabled', (
    tester,
  ) async {
    final controller = ModuleStatusMonitorController();
    final disabledProfile = NotificationRuleProfile.official()
        .withEventSetting(
          NotificationEventType.moduleDisconnected,
          const NotificationEventSetting(enabled: false),
        );
    await _pumpSidePanel(
      tester,
      controller: controller,
      profile: disabledProfile,
    );

    controller.observe(const ModuleStatusReading({
      RobotModuleType.videoTransmission: ModuleAvailability.offline,
    }));
    await tester.pumpAndSettle();

    expect(find.text('模块状态'), findsOneWidget);
  });

  testWidgets('keeps recording events while module panel is shown', (
    tester,
  ) async {
    final controller = ModuleStatusMonitorController();
    final gameState = GameStateNotifier();
    await _pumpSidePanel(
      tester,
      controller: controller,
      gameState: gameState,
    );
    controller.observe(const ModuleStatusReading({
      RobotModuleType.videoTransmission: ModuleAvailability.offline,
    }));
    await tester.pumpAndSettle();

    final event = Event(eventId: 14, param: '');
    gameState.handleEnvelope(
      ProtobufEnvelope(
        topic: topicEvent,
        messageType: topicEvent,
        protobufMessage: event,
        rawBytes: event.writeToBuffer(),
        timestamp: DateTime(2026, 7, 22, 12),
      ),
    );
    controller.observe(const ModuleStatusReading({
      RobotModuleType.videoTransmission: ModuleAvailability.online,
    }));
    await tester.pumpAndSettle();

    expect(find.text('四级装配请求'), findsOneWidget);
  });
}

Future<void> _pumpSidePanel(
  WidgetTester tester, {
  required ModuleStatusMonitorController controller,
  GameStateNotifier? gameState,
  NotificationRuleProfile? profile,
}) {
  final notifier = gameState ?? GameStateNotifier();
  final activeProfile = profile ?? NotificationRuleProfile.official();
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        moduleStatusMonitorProvider.overrideWith((ref) => controller),
        gameStateProvider.overrideWith((ref) => notifier),
        activeNotificationProfileProvider.overrideWithValue(activeProfile),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardSidePanel())),
    ),
  );
}
