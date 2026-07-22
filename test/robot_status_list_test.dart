import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/state/session_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/game_state.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/robot_status_list.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('enemy detail mode does not render a focus-fire suggestion', (
    tester,
  ) async {
    final status = GlobalUnitStatus()
      ..robotHealth.addAll([500, 300, 300, 300, 600, 1, 300, 300, 300, 600]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: RobotStatusList(
                gameState: GameState(globalUnitStatus: status),
                ownIsBlueOverride: false,
                modeOverride: DashboardDisplayMode.enemyFocus,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.textContaining('集火目标'), findsNothing);
    expect(find.byIcon(Icons.whatshot), findsNothing);
  });

  test(
    'production UI and active mode description contain no focus-fire copy',
    () {
      final sourceFiles = [
        File(
          'lib/features/dashboard/presentation/widgets/robot_status_list.dart',
        ),
        File('lib/core/state/session_providers.dart'),
      ];

      for (final file in sourceFiles) {
        expect(
          file.readAsStringSync(),
          isNot(contains('集火')),
          reason: file.path,
        );
      }
      expect(
        DashboardDisplayMode.enemyFocus.description,
        '机器人列表展示敌方逐个血量，便于快速查看各机器人状态；下方趋势图展示己方总血量。',
      );
    },
  );
}
