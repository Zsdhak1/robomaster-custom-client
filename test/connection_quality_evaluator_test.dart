// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/connection_quality_evaluator.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';

void main() {
  _testDebouncedRecovery();
  _testCriticalThresholds();
}

void _testDebouncedRecovery() {
  test('debounces degradation and requires stable recovery', () {
    final evaluator = ConnectionQualityEvaluator();
    const config = ConnectionQualityRuleConfig(
      mqttWarningSeconds: 2,
      mqttCriticalSeconds: 5,
      debounceMilliseconds: 1000,
      recoveryStableSeconds: 2,
    );
    final start = DateTime(2026, 7, 13, 12);

    expect(
      evaluator.evaluate(_metrics(start, mqttStale: 3000), config),
      isNull,
    );
    expect(
      evaluator.evaluate(
        _metrics(start.add(const Duration(milliseconds: 500)), mqttStale: 3500),
        config,
      ),
      isNull,
    );
    final degraded = evaluator.evaluate(
      _metrics(start.add(const Duration(seconds: 1)), mqttStale: 4000),
      config,
    );
    expect(degraded?.type, NotificationEventType.connectionQualityChanged);
    expect(evaluator.current, ConnectionQualityLevel.warning);

    expect(
      evaluator.evaluate(
        _metrics(start.add(const Duration(seconds: 2))),
        config,
      ),
      isNull,
    );
    final recovered = evaluator.evaluate(
      _metrics(start.add(const Duration(seconds: 4))),
      config,
    );
    expect(recovered?.headline, contains('恢复'));
    expect(evaluator.current, ConnectionQualityLevel.good);
  });
}

void _testCriticalThresholds() {
  test('uses UDP and custom video critical thresholds', () {
    final evaluator = ConnectionQualityEvaluator();
    const config = ConnectionQualityRuleConfig(debounceMilliseconds: 0);
    final start = DateTime(2026, 7, 13, 12);
    final critical = _metrics(
      start,
      udpLoss: 20,
      customRunning: true,
      customStale: 3000,
    );
    expect(evaluator.evaluate(critical, config), isNull);
    final event = evaluator.evaluate(
      _metrics(
        start.add(const Duration(milliseconds: 1)),
        udpLoss: 20,
        customRunning: true,
        customStale: 3001,
      ),
      config,
    );
    expect(event?.headline, contains('严重'));
    expect(evaluator.current, ConnectionQualityLevel.critical);
  });
}

ConnectionQualityMetrics _metrics(
  DateTime timestamp, {
  int mqttStale = 0,
  double? udpLoss,
  bool customRunning = false,
  int? customStale,
}) {
  return ConnectionQualityMetrics(
    timestamp: timestamp,
    mqttConnected: true,
    millisSinceLastMqttMessage: mqttStale,
    udpActive: udpLoss != null,
    udpLossPercent: udpLoss,
    customVideoRunning: customRunning,
    millisSinceLastCustomChunk: customStale,
    decoderClients: 0,
    millisSinceLastKeyframe: null,
  );
}
