/// v0.1.2 仪表盘血量估算与比赛详情组件测试。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/navigation/app_shell.dart';
import 'package:robomaster_custom_client_1/core/responsive/desktop_design_canvas.dart';
import 'package:robomaster_custom_client_1/core/responsive/desktop_design_scope.dart';
import 'package:robomaster_custom_client_1/core/theme/app_theme.dart';
import 'package:robomaster_custom_client_1/core/widgets/video_side_panel.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/game_state.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/dashboard_screen.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/game_status_card.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/robot_status_list.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('robot row shows expected projectile estimate', (tester) async {
    final health = GlobalUnitStatus()
      ..robotHealth.addAll([500, 300, 300, 300, 600, 100, 300, 300, 300, 600]);
    await _pump(
      tester,
      RobotStatusList(
        gameState: GameState(globalUnitStatus: health),
        ownIsBlueOverride: false,
      ),
    );

    expect(find.text('预计弹丸'), findsNWidgets(4));
    expect(find.text('1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing health data shows a scanning glow', (tester) async {
    await _pump(
      tester,
      const RobotStatusList(gameState: GameState(), ownIsBlueOverride: false),
    );

    expect(
      find.byKey(const ValueKey<String>('health-scan-glow')),
      findsNWidgets(4),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('game status fills details from aggregated state', (
    tester,
  ) async {
    final status = GameStatus(
      currentRound: 2,
      totalRounds: 3,
      redScore: 1,
      blueScore: 0,
      currentStage: 4,
      stageCountdownSec: 120,
      stageElapsedSec: 60,
      isPaused: true,
    );
    final logistics = GlobalLogisticsStatus(
      remainingEconomy: 800,
      techLevel: 2,
      encryptionLevel: 3,
    );
    await _pump(
      tester,
      GameStatusCard(
        gameState: GameState(
          gameStatus: status,
          globalLogisticsStatus: logistics,
        ),
      ),
    );

    expect(find.text('比赛中'), findsOneWidget);
    expect(find.text('第 2 / 3 回合'), findsOneWidget);
    expect(find.text('红 1 : 0 蓝'), findsOneWidget);
    expect(find.text('比赛暂停'), findsOneWidget);
    expect(find.text('经济 800'), findsOneWidget);
    expect(find.text('科技 Lv.2 · 加密 Lv.3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard fits a 3:2 desktop canvas without overflow', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTeamTheme(rmRedTeamColor),
            home: const DesktopDesignCanvas(child: DashboardScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('video side health panel fits when debug details are visible', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTeamTheme(rmRedTeamColor),
            home: const DesktopDesignScope(
              componentScale: 1,
              child: SizedBox(
                width: 400,
                height: 640,
                child: VideoSidePanel(
                  title: '视频流状态',
                  basicInfo: Text('未开始接收'),
                  developerMode: true,
                  debugSection: SizedBox(height: 180),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop AppShell paints the dashboard body', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customVideoStatsProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
          ],
          child: MaterialApp(
            theme: buildTeamTheme(rmRedTeamColor),
            home: const DesktopDesignCanvas(child: AppShell()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('未连接（离线模式）'), findsOneWidget);
      expect(find.text('连接质量'), findsOneWidget);
      expect(tester.getSize(find.byType(DashboardScreen)).height, 720);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTeamTheme(rmRedTeamColor),
        home: Scaffold(body: SizedBox(width: 1000, height: 600, child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
}
