import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/state/session_providers.dart';
import 'package:robomaster_custom_client_1/core/theme/app_theme.dart';
import 'package:robomaster_custom_client_1/features/dashboard/data/operation_command_service.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/operation_panel_controller.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/operation_panel.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';

void main() {
  group('combat operation panel', _combatPanelTests);
  group('availability pulse', _availabilityPulseTests);
  group('engineer operation panel', _engineerPanelTests);
}

void _combatPanelTests() {
  testWidgets('hero keeps three actions and removes respawn confirmation', (
    tester,
  ) async {
    final controller = _controllerFor(1);
    await _pumpOperationPanel(tester, controller: controller, robotId: 1);

    expect(find.text('请求复活'), findsNothing);
    expect(find.text('英雄 · 42mm'), findsOneWidget);
    expect(find.text('买弹 × 10'), findsOneWidget);
    expect(find.text('远程买血'), findsOneWidget);
    expect(find.text('远程买弹'), findsOneWidget);
    expect(find.byKey(const ValueKey('remote-heal-pulse')), findsOneWidget);
    expect(find.byKey(const ValueKey('remote-ammo-pulse')), findsOneWidget);
  });

  testWidgets('unknown telemetry disables remote actions with exact reason', (
    tester,
  ) async {
    final controller = _controllerFor(1);
    await _pumpOperationPanel(tester, controller: controller, robotId: 1);

    final remoteHeal = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '远程买血'),
    );
    final remoteAmmo = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '远程买弹'),
    );
    expect(remoteHeal.onPressed, isNull);
    expect(remoteAmmo.onPressed, isNull);
    expect(find.text('等待机器人实时状态'), findsNWidgets(2));
  });

  testWidgets('normal ammo purchase allows selecting the quantity', (
    tester,
  ) async {
    final controller = _controllerFor(1);
    await _pumpOperationPanel(tester, controller: controller, robotId: 1);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30').last);
    await tester.pumpAndSettle();

    expect(find.text('买弹 × 30'), findsOneWidget);
    expect(controller.state.ammoQuantity, 30);
  });
}

void _availabilityPulseTests() {
  testWidgets('false to true enables action and plays one finite pulse', (
    tester,
  ) async {
    final controller = _controllerFor(1)..handleMessage(RobotDynamicStatus());
    await _pumpOperationPanel(tester, controller: controller, robotId: 1);

    controller.handleMessage(RobotDynamicStatus(canRemoteHeal: true));
    await tester.pump();
    final remoteHeal = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '远程买血'),
    );
    expect(remoteHeal.onPressed, isNotNull);

    await tester.pump(const Duration(milliseconds: 350));
    expect(_pulseBlur(tester, 'remote-heal-pulse-glow'), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_pulseBlur(tester, 'remote-heal-pulse-glow'), 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(_pulseBlur(tester, 'remote-heal-pulse-glow'), 0);
  });
}

void _engineerPanelTests() {
  testWidgets('engineer renders protocol difficulty steps and remaining time', (
    tester,
  ) async {
    final controller = _controllerFor(2)
      ..handleMessage(
        TechCoreMotionStateSync(
          maximumDifficultyLevel: 2,
          basicState: 2,
          putinState: 1,
          moveState: 0,
          rotateState: 0,
          remainTimeAll: 18,
          remainTimeStep: 4,
        ),
      );
    await _pumpOperationPanel(tester, controller: controller, robotId: 2);

    expect(find.text('Lv.1'), findsOneWidget);
    expect(find.text('Lv.2'), findsOneWidget);
    expect(find.text('Lv.3'), findsNothing);
    expect(find.text('Lv.4'), findsNothing);
    expect(find.text('科技核心运动中'), findsOneWidget);
    expect(find.text('已放入'), findsOneWidget);
    expect(find.text('等待平移'), findsOneWidget);
    expect(find.text('等待旋转'), findsOneWidget);
    expect(find.text('总剩余 18 秒'), findsOneWidget);
    expect(find.text('步骤剩余 4 秒'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engineer content remains scrollable at narrow height', (
    tester,
  ) async {
    final controller = _controllerFor(2)
      ..handleMessage(TechCoreMotionStateSync(maximumDifficultyLevel: 4));
    await _pumpOperationPanel(
      tester,
      controller: controller,
      robotId: 2,
      height: 150,
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

OperationPanelController _controllerFor(int robotId) {
  return OperationPanelController(
    commands: OperationCommandService(publish: (_, _) {}),
    repeatFactory: (_, _) => _NoopRepeater(),
    connected: true,
    robotId: robotId,
  );
}

Future<void> _pumpOperationPanel(
  WidgetTester tester, {
  required OperationPanelController controller,
  required int robotId,
  double height = 220,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedRobotIdProvider.overrideWith((ref) => robotId),
        operationPanelControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        theme: buildTeamTheme(rmRedTeamColor),
        home: Scaffold(
          body: SizedBox(
            width: 720,
            height: height,
            child: const OperationPanel(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _pulseBlur(WidgetTester tester, String key) {
  final decoration = tester.widget<DecoratedBox>(find.byKey(ValueKey(key)));
  final boxDecoration = decoration.decoration as BoxDecoration;
  return boxDecoration.boxShadow!.single.blurRadius;
}

class _NoopRepeater implements OperationRepeater {
  @override
  void cancel() {}
}
