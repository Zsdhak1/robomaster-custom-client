/// MQTT、UDP 和自定义图传连接质量的防抖评估器。
library;

import '../../settings/domain/combat_notification_rules.dart';
import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';

/// 综合连接质量级别。
enum ConnectionQualityLevel { good, warning, critical }

/// 单次连接质量采样。
class ConnectionQualityMetrics {
  /// 创建连接质量采样。
  const ConnectionQualityMetrics({
    required this.timestamp,
    required this.mqttConnected,
    required this.millisSinceLastMqttMessage,
    required this.udpActive,
    required this.udpLossPercent,
    required this.customVideoRunning,
    required this.millisSinceLastCustomChunk,
    required this.decoderClients,
    required this.millisSinceLastKeyframe,
  });

  final DateTime timestamp;
  final bool mqttConnected;
  final int? millisSinceLastMqttMessage;
  final bool udpActive;
  final double? udpLossPercent;
  final bool customVideoRunning;
  final int? millisSinceLastCustomChunk;
  final int decoderClients;
  final int? millisSinceLastKeyframe;
}

/// 对质量变化执行降级防抖和稳定恢复。
class ConnectionQualityEvaluator {
  ConnectionQualityLevel _current = ConnectionQualityLevel.good;
  ConnectionQualityLevel? _pending;
  DateTime? _pendingSince;

  /// 当前已确认的质量级别。
  ConnectionQualityLevel get current => _current;

  /// 新比赛或新会话开始时恢复初始状态。
  void reset() {
    _current = ConnectionQualityLevel.good;
    _clearPending();
  }

  /// 评估一次采样；仅在确认发生级别变化时返回通知。
  RuleNotificationEvent? evaluate(
    ConnectionQualityMetrics metrics,
    ConnectionQualityRuleConfig config,
  ) {
    final evaluation = _rawEvaluation(metrics, config);
    if (evaluation.level == _current) {
      _clearPending();
      return null;
    }
    if (_pending != evaluation.level) {
      _pending = evaluation.level;
      _pendingSince = metrics.timestamp;
      return null;
    }
    final since = _pendingSince;
    if (since == null || !_debounceElapsed(metrics, config, since)) return null;
    _current = evaluation.level;
    _clearPending();
    return _qualityEvent(evaluation, metrics.timestamp);
  }

  _QualityEvaluation _rawEvaluation(
    ConnectionQualityMetrics metrics,
    ConnectionQualityRuleConfig config,
  ) {
    final warning = <String>[];
    final critical = <String>[];
    _evaluateMqtt(metrics, config, warning, critical);
    _evaluateUdp(metrics, config, warning, critical);
    _evaluateCustomVideo(metrics, config, critical);
    if (critical.isNotEmpty) {
      return _QualityEvaluation(ConnectionQualityLevel.critical, critical);
    }
    if (warning.isNotEmpty) {
      return _QualityEvaluation(ConnectionQualityLevel.warning, warning);
    }
    return const _QualityEvaluation(ConnectionQualityLevel.good, ['各链路指标已恢复']);
  }

  void _evaluateMqtt(
    ConnectionQualityMetrics metrics,
    ConnectionQualityRuleConfig config,
    List<String> warning,
    List<String> critical,
  ) {
    if (!metrics.mqttConnected) return;
    final stale = metrics.millisSinceLastMqttMessage;
    if (stale == null) return;
    if (stale >= config.mqttCriticalSeconds * 1000) {
      critical.add('MQTT 已 ${stale ~/ 1000} 秒无消息');
    } else if (stale >= config.mqttWarningSeconds * 1000) {
      warning.add('MQTT 已 ${stale ~/ 1000} 秒无消息');
    }
  }

  void _evaluateUdp(
    ConnectionQualityMetrics metrics,
    ConnectionQualityRuleConfig config,
    List<String> warning,
    List<String> critical,
  ) {
    final loss = metrics.udpLossPercent;
    if (!metrics.udpActive || loss == null) return;
    final text = 'UDP 窗口丢包率 ${loss.toStringAsFixed(1)}%';
    if (loss >= config.udpCriticalLossPercent) {
      critical.add(text);
    } else if (loss >= config.udpWarningLossPercent) {
      warning.add(text);
    }
  }

  void _evaluateCustomVideo(
    ConnectionQualityMetrics metrics,
    ConnectionQualityRuleConfig config,
    List<String> critical,
  ) {
    if (!metrics.customVideoRunning) return;
    final chunkStale = metrics.millisSinceLastCustomChunk;
    if (chunkStale != null &&
        chunkStale >= config.customVideoStaleSeconds * 1000) {
      critical.add('自定义图传已 ${chunkStale ~/ 1000} 秒无数据块');
    }
    final keyframeStale = metrics.millisSinceLastKeyframe;
    if (metrics.decoderClients > 0 &&
        keyframeStale != null &&
        keyframeStale >= config.decoderStaleSeconds * 1000) {
      critical.add('解码链路已 ${keyframeStale ~/ 1000} 秒无关键帧');
    }
  }

  bool _debounceElapsed(
    ConnectionQualityMetrics metrics,
    ConnectionQualityRuleConfig config,
    DateTime since,
  ) {
    final required = _pending == ConnectionQualityLevel.good
        ? Duration(seconds: config.recoveryStableSeconds)
        : Duration(milliseconds: config.debounceMilliseconds);
    return metrics.timestamp.difference(since) >= required;
  }

  RuleNotificationEvent _qualityEvent(
    _QualityEvaluation evaluation,
    DateTime timestamp,
  ) {
    final recovered = evaluation.level == ConnectionQualityLevel.good;
    final headline = switch (evaluation.level) {
      ConnectionQualityLevel.good => '连接质量已恢复',
      ConnectionQualityLevel.warning => '连接质量下降',
      ConnectionQualityLevel.critical => '连接质量严重下降',
    };
    return RuleNotificationEvent(
      type: NotificationEventType.connectionQualityChanged,
      headline: headline,
      detail: evaluation.reasons.join('；'),
      dedupKey: recovered
          ? 'connection-quality-recovered'
          : 'connection-quality-degraded',
      recoveryKey: recovered ? 'connection-quality-degraded' : null,
      occurredAt: timestamp,
    );
  }

  void _clearPending() {
    _pending = null;
    _pendingSince = null;
  }
}

class _QualityEvaluation {
  const _QualityEvaluation(this.level, this.reasons);

  final ConnectionQualityLevel level;
  final List<String> reasons;
}
