import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/features/settings/logic/notification_profile_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('official profile is read-only and custom copy persists', () async {
    final notifier = NotificationProfileNotifier();
    await notifier.loaded;
    final officialDuration =
        notifier.state.activeProfile.display.infoDurationSeconds;

    await notifier.updateDisplay(
      const NotificationDisplayConfig(infoDurationSeconds: 9),
    );
    expect(
      notifier.state.activeProfile.display.infoDurationSeconds,
      officialDuration,
    );

    await notifier.duplicateActive(name: '现场配置');
    await notifier.updateDisplay(
      notifier.state.activeProfile.display.copyWith(infoDurationSeconds: 9),
    );
    expect(notifier.state.activeProfile.name, '现场配置');
    expect(notifier.state.activeProfile.display.infoDurationSeconds, 9);
    notifier.dispose();

    final restored = NotificationProfileNotifier();
    await restored.loaded;
    expect(restored.state.activeProfile.name, '现场配置');
    expect(restored.state.activeProfile.display.infoDurationSeconds, 9);
    restored.dispose();
  });

  test('imported JSON becomes an editable active profile', () async {
    final notifier = NotificationProfileNotifier();
    await notifier.loaded;

    final imported = await notifier.importJson('''
      {
        "schema_version": 1,
        "profile_name": "导入档案",
        "display": {"enabled": false}
      }
    ''');

    expect(imported.isOfficial, isFalse);
    expect(notifier.state.activeProfile.name, '导入档案');
    expect(notifier.state.activeProfile.display.enabled, isFalse);
    notifier.dispose();
  });
}
