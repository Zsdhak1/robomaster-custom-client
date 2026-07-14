import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/navigation/app_shell.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_controller.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_models.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/deployment_navigation_controller.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_providers.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  _testGlobalNotifications();
  _testDeploymentCountdown();
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
