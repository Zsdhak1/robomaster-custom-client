import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/responsive/design_constants.dart';
import 'package:robomaster_custom_client_1/core/theme/app_theme.dart';
import 'package:robomaster_custom_client_1/core/window/desktop_window_frame.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/features/settings/logic/notification_test_provider.dart';
import 'package:robomaster_custom_client_1/features/settings/presentation/notification_rules_settings_screen.dart';
import 'package:robomaster_custom_client_1/features/settings/presentation/notification_settings_strings.dart';
import 'package:robomaster_custom_client_1/features/settings/presentation/notification_settings_subpages.dart';
import 'package:robomaster_custom_client_1/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  _testDirectoryNavigation();
  _testProfileCopy();
  _testManualNotificationRequests();
  _testSettingDescriptions();
  _testEmbeddedNavigation();
  _testOpaqueEmbeddedTransition();
  _testWindowsBackButtonHitTarget();
}

void _testDirectoryNavigation() {
  testWidgets('shows six grouped notification settings destinations', (
    tester,
  ) async {
    await _pumpSettings(tester, dispatcher: (_) => true);

    expect(find.text(notificationManagementGroupTitle), findsOneWidget);
    expect(find.text(notificationRulesGroupTitle), findsOneWidget);
    for (final title in _destinationTitles) {
      expect(find.text(title), findsOneWidget);
    }

    await _openPage(tester, notificationConnectionPageTitle);
    expect(find.text(notificationMqttWarningDescription), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(notificationDirectoryTitle), findsOneWidget);
  });
}

void _testProfileCopy() {
  testWidgets('opens profile page and creates editable copy', (tester) async {
    await _pumpSettings(tester, dispatcher: (_) => true);
    await _openPage(tester, notificationProfilePageTitle);

    expect(find.text(notificationProfileReadOnly), findsOneWidget);
    await tester.tap(find.text(notificationProfileCopy));
    await tester.pumpAndSettle();

    expect(find.text(notificationProfileEditable), findsOneWidget);
    expect(find.text(notificationProfileDelete), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _testManualNotificationRequests() {
  testWidgets('dispatches severity and event notification tests', (
    tester,
  ) async {
    NotificationTestRequest? request;
    await _pumpSettings(
      tester,
      dispatcher: (next) {
        request = next;
        return true;
      },
    );
    await _openPage(tester, notificationDisplayTestPageTitle);

    await _scrollTo(tester, find.text(notificationTestInfo));
    await tester.tap(find.text(notificationTestInfo));
    expect(request?.severityOverride, NotificationSeverity.info);

    final eventChip = find.widgetWithText(ActionChip, '敌方买活');
    await _scrollTo(tester, eventChip);
    await tester.tap(eventChip);
    expect(request?.type, NotificationEventType.enemyBoughtRespawn);
    expect(request?.severityOverride, isNull);
  });
}

void _testSettingDescriptions() {
  testWidgets('keeps concrete descriptions in every subpage', (tester) async {
    await _pumpSettings(tester, dispatcher: (_) => true);

    await _verifyPageDescription(
      tester,
      notificationProfilePageTitle,
      notificationProfileSectionSubtitle,
    );
    await _verifyPageDescription(
      tester,
      notificationDisplayTestPageTitle,
      notificationEnabledDescription,
    );
    await _verifyPageDescription(
      tester,
      notificationEventsPageTitle,
      notificationEventDescription(NotificationEventType.mqttDisconnected),
    );
    await _verifyPageDescription(
      tester,
      notificationCombatRulesPageTitle,
      notificationRespawnEnabledDescription,
    );
    await _verifyPageDescription(
      tester,
      notificationDeploymentPageTitle,
      notificationDeploymentEnabledDescription,
    );
    await _verifyPageDescription(
      tester,
      notificationConnectionPageTitle,
      notificationMqttWarningDescription,
    );
    expect(tester.takeException(), isNull);
  });
}

void _testEmbeddedNavigation() {
  testWidgets('keeps second-level navigation inside wide detail pane', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      const SettingsScreen(),
      dispatcher: (_) => true,
      size: const Size(1200, 900),
    );

    await tester.tap(find.text(notificationSettingsCategoryTitle).first);
    await tester.pumpAndSettle();
    await _openPage(tester, notificationDeploymentPageTitle);
    expect(find.text(notificationDeploymentEnabledDescription), findsOneWidget);

    await tester.tap(find.byTooltip('返回设置目录'));
    await tester.pumpAndSettle();
    expect(find.text(notificationDirectoryTitle), findsOneWidget);
    expect(find.text('常规'), findsOneWidget);
  });
}

void _testOpaqueEmbeddedTransition() {
  testWidgets('paints an opaque surface during embedded page transition', (
    tester,
  ) async {
    await _pumpWidget(
      tester,
      const SettingsScreen(),
      dispatcher: (_) => true,
      size: const Size(1200, 900),
    );
    await tester.tap(find.text(notificationSettingsCategoryTitle).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(notificationProfilePageTitle));
    await tester.pump(const Duration(milliseconds: 100));

    final surface = find.byKey(notificationSettingsSubpageSurfaceKey);
    final nestedNavigator = find.byType(Navigator).last;
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface), tester.getSize(nestedNavigator));
    final box = tester.widget<ColoredBox>(surface);
    expect(box.color, buildTeamTheme(rmRedTeamColor).colorScheme.surface);
  });
}

void _testWindowsBackButtonHitTarget() {
  testWidgets('Windows drag layer does not cover the back button center', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.windows, () async {
      _mockWindowChannel(tester);
      await _pumpWidget(
        tester,
        const DesktopWindowFrame(child: SettingsScreen()),
        dispatcher: (_) => true,
        size: const Size(1200, 900),
      );
      await tester.tap(find.text(notificationSettingsCategoryTitle).first);
      await tester.pumpAndSettle();
      await _openPage(tester, notificationDeploymentPageTitle);

      final backButton = find.byTooltip('返回设置目录');
      expect(
        tester.getTopLeft(backButton).dy,
        greaterThanOrEqualTo(desktopTitleBarHeight),
      );
      await tester.tapAt(tester.getCenter(backButton));
      await tester.pumpAndSettle();
      expect(find.text(notificationDirectoryTitle), findsOneWidget);
    });
  });
}

const _destinationTitles = [
  notificationProfilePageTitle,
  notificationDisplayTestPageTitle,
  notificationEventsPageTitle,
  notificationCombatRulesPageTitle,
  notificationDeploymentPageTitle,
  notificationConnectionPageTitle,
];

Future<void> _verifyPageDescription(
  WidgetTester tester,
  String pageTitle,
  String description,
) async {
  await _openPage(tester, pageTitle);
  final finder = find.textContaining(description);
  await _scrollTo(tester, finder);
  expect(finder, findsOneWidget);
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> _openPage(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required NotificationTestDispatcher dispatcher,
}) {
  return _pumpWidget(
    tester,
    const NotificationRulesSettingsScreen(),
    dispatcher: dispatcher,
    size: const Size(1000, 1200),
  );
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget home, {
  required NotificationTestDispatcher dispatcher,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationTestDispatcherProvider.overrideWithValue(dispatcher),
      ],
      child: MaterialApp(theme: buildTeamTheme(rmRedTeamColor), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void _mockWindowChannel(WidgetTester tester) {
  const channel = MethodChannel('wod_client/window');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => call.method == 'isMaximized' ? false : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    ),
  );
}

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
