import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/theme/app_theme.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/operation_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('normal ammo purchase allows selecting the quantity', (
    tester,
  ) async {
    await _pumpOperationPanel(tester);

    expect(find.text('买弹 × 10'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    expect(find.text('买弹 × 30'), findsOneWidget);
  });

  testWidgets('operation actions use elevated filled buttons', (tester) async {
    await _pumpOperationPanel(tester);

    final buttons = tester.widgetList<FilledButton>(find.byType(FilledButton));
    final elevatedButtons = buttons.where(
      (button) => button.style?.elevation?.resolve({}) == 2,
    );
    expect(elevatedButtons, hasLength(4));
  });
}

Future<void> _pumpOperationPanel(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTeamTheme(rmRedTeamColor),
        home: const Scaffold(
          body: SizedBox(width: 720, height: 220, child: OperationPanel()),
        ),
      ),
    ),
  );
  await tester.pump();
}
