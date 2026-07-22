import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/kill_estimate_config.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_rule_profile.dart';

void main() {
  group('NotificationRuleProfile', () {
    _testJsonRoundTrip();
    _testImportedValueClamping();
    _testUnsupportedSchema();
    _testOfficialDefaults();
  });
}

void _testOfficialDefaults() {
  test('official profile matches 2026 V2.0.0 notification defaults', () {
    final profile = NotificationRuleProfile.official();

    expect(profile.ruleVersion, '2.0.0');
    expect(
      profile.eventSettings[NotificationEventType.enemyRespawned]?.severity,
      NotificationSeverity.info,
    );
    expect(
      profile.eventSettings[NotificationEventType.enemyBoughtRespawn]?.severity,
      NotificationSeverity.critical,
    );
    expect(defaultSmallProjectileDamage, 20);
    expect(defaultLargeProjectileDamage, 200);
  });
}

void _testJsonRoundTrip() {
  test('round-trips all rule groups through JSON', () {
    final source = NotificationRuleProfile.official()
        .customCopy(id: 'custom-1', name: '训练赛规则')
        .copyWith(
          display: const NotificationDisplayConfig(infoDurationSeconds: 8),
          killLine: const KillLineRuleConfig(heroThreshold: 2),
          respawn: const RespawnRuleConfig(toleranceMilliseconds: 2000),
          deploymentNavigation: const DeploymentNavigationConfig(
            countdownSeconds: 5,
          ),
          connectionQuality: const ConnectionQualityRuleConfig(
            mqttWarningSeconds: 4,
          ),
        );

    final restored = NotificationRuleProfile.fromJson(source.toJson());

    expect(restored.name, '训练赛规则');
    expect(restored.isOfficial, isFalse);
    expect(restored.display.infoDurationSeconds, 8);
    expect(restored.killLine.heroThreshold, 2);
    expect(restored.respawn.toleranceMilliseconds, 2000);
    expect(restored.deploymentNavigation.countdownSeconds, 5);
    expect(restored.connectionQuality.mqttWarningSeconds, 4);
    expect(
      restored
          .eventSettings[NotificationEventType.moduleDisconnected]
          ?.severity,
      NotificationSeverity.critical,
    );
  });
}

void _testImportedValueClamping() {
  test('clamps unsafe imported values', () {
    final profile = NotificationRuleProfile.fromJson({
      'schema_version': 1,
      'display': {'info_duration_seconds': 99, 'max_visible_info': 0},
      'kill_line': {'hero_threshold': 0},
      'respawn': {'time_divisor': 0},
      'deployment_navigation': {'countdown_seconds': 99},
      'connection_quality': {
        'mqtt_warning_seconds': 20,
        'mqtt_critical_seconds': 5,
        'udp_warning_loss_percent': 30,
        'udp_critical_loss_percent': 10,
      },
    });

    expect(profile.display.infoDurationSeconds, 15);
    expect(profile.display.maxVisibleInfo, 1);
    expect(profile.killLine.heroThreshold, 1);
    expect(profile.respawn.timeDivisor, 1);
    expect(profile.deploymentNavigation.countdownSeconds, 10);
    expect(profile.connectionQuality.mqttWarningSeconds, 20);
    expect(profile.connectionQuality.mqttCriticalSeconds, 20);
    expect(profile.connectionQuality.udpCriticalLossPercent, 30);
  });
}

void _testUnsupportedSchema() {
  test('rejects newer unsupported schema versions', () {
    expect(
      () => NotificationRuleProfile.fromJson({'schema_version': 999}),
      throwsFormatException,
    );
  });
}
