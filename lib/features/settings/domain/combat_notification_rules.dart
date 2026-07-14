/// 战术判定、部署跳转和连接质量规则模型。
library;

/// 斩杀线的计算方式。
enum KillLineMode { expectedProjectiles, healthPercent, fixedHealth }

/// 无法确定敌方买活时的展示策略。
enum UncertainBuybackBehavior { suppress, suspected }

/// 敌方斩杀线配置。
class KillLineRuleConfig {
  /// 创建斩杀线配置。
  const KillLineRuleConfig({
    this.enabled = true,
    this.mode = KillLineMode.expectedProjectiles,
    this.heroThreshold = 3,
    this.infantryThreshold = 3,
    this.sentryThreshold = 3,
    this.healthPercentThreshold = 20,
    this.fixedHealthThreshold = 200,
    this.cooldownSeconds = 5,
    this.rearmDelta = 1,
  });

  /// 从 JSON 创建配置。
  factory KillLineRuleConfig.fromJson(Map<String, dynamic> json) {
    return KillLineRuleConfig(
      enabled: _bool(json['enabled'], true),
      mode: _enumValue(
        KillLineMode.values,
        json['mode'],
        KillLineMode.expectedProjectiles,
      ),
      heroThreshold: _boundedInt(json['hero_threshold'], 3, 1, 20),
      infantryThreshold: _boundedInt(json['infantry_threshold'], 3, 1, 20),
      sentryThreshold: _boundedInt(json['sentry_threshold'], 3, 1, 20),
      healthPercentThreshold: _boundedInt(
        json['health_percent_threshold'],
        20,
        1,
        100,
      ),
      fixedHealthThreshold: _boundedInt(
        json['fixed_health_threshold'],
        200,
        1,
        10000,
      ),
      cooldownSeconds: _boundedInt(json['cooldown_seconds'], 5, 0, 60),
      rearmDelta: _boundedInt(json['rearm_delta'], 1, 1, 10),
    );
  }

  final bool enabled;
  final KillLineMode mode;
  final int heroThreshold;
  final int infantryThreshold;
  final int sentryThreshold;
  final int healthPercentThreshold;
  final int fixedHealthThreshold;
  final int cooldownSeconds;
  final int rearmDelta;

  /// 创建修改后的副本。
  KillLineRuleConfig copyWith({
    bool? enabled,
    KillLineMode? mode,
    int? heroThreshold,
    int? infantryThreshold,
    int? sentryThreshold,
    int? healthPercentThreshold,
    int? fixedHealthThreshold,
    int? cooldownSeconds,
    int? rearmDelta,
  }) {
    return KillLineRuleConfig(
      enabled: enabled ?? this.enabled,
      mode: mode ?? this.mode,
      heroThreshold: (heroThreshold ?? this.heroThreshold).clamp(1, 20),
      infantryThreshold: (infantryThreshold ?? this.infantryThreshold).clamp(
        1,
        20,
      ),
      sentryThreshold: (sentryThreshold ?? this.sentryThreshold).clamp(1, 20),
      healthPercentThreshold:
          (healthPercentThreshold ?? this.healthPercentThreshold).clamp(1, 100),
      fixedHealthThreshold: (fixedHealthThreshold ?? this.fixedHealthThreshold)
          .clamp(1, 10000),
      cooldownSeconds: (cooldownSeconds ?? this.cooldownSeconds).clamp(0, 60),
      rearmDelta: (rearmDelta ?? this.rearmDelta).clamp(1, 10),
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mode': mode.name,
    'hero_threshold': heroThreshold,
    'infantry_threshold': infantryThreshold,
    'sentry_threshold': sentryThreshold,
    'health_percent_threshold': healthPercentThreshold,
    'fixed_health_threshold': fixedHealthThreshold,
    'cooldown_seconds': cooldownSeconds,
    'rearm_delta': rearmDelta,
  };
}

/// 敌方复活和买活判定参数。
class RespawnRuleConfig {
  /// 创建复活规则。
  const RespawnRuleConfig({
    this.enabled = true,
    this.buybackDetectionEnabled = true,
    this.baseProgress = 10,
    this.matchDurationSeconds = 420,
    this.timeDivisor = 10,
    this.progressPenaltyPerBuyback = 20,
    this.normalProgressPerSecond = 1,
    this.acceleratedProgressPerSecond = 4,
    this.lowBaseHealthThreshold = 2000,
    this.toleranceMilliseconds = 1500,
    this.uncertainBehavior = UncertainBuybackBehavior.suspected,
  });

  /// 从 JSON 创建配置。
  factory RespawnRuleConfig.fromJson(Map<String, dynamic> json) {
    return RespawnRuleConfig(
      enabled: _bool(json['enabled'], true),
      buybackDetectionEnabled: _bool(json['buyback_detection_enabled'], true),
      baseProgress: _boundedInt(json['base_progress'], 10, 1, 300),
      matchDurationSeconds: _boundedInt(
        json['match_duration_seconds'],
        420,
        60,
        3600,
      ),
      timeDivisor: _boundedInt(json['time_divisor'], 10, 1, 300),
      progressPenaltyPerBuyback: _boundedInt(
        json['progress_penalty_per_buyback'],
        20,
        0,
        300,
      ),
      normalProgressPerSecond: _boundedInt(
        json['normal_progress_per_second'],
        1,
        1,
        20,
      ),
      acceleratedProgressPerSecond: _boundedInt(
        json['accelerated_progress_per_second'],
        4,
        1,
        20,
      ),
      lowBaseHealthThreshold: _boundedInt(
        json['low_base_health_threshold'],
        2000,
        0,
        100000,
      ),
      toleranceMilliseconds: _boundedInt(
        json['tolerance_milliseconds'],
        1500,
        0,
        5000,
      ),
      uncertainBehavior: _enumValue(
        UncertainBuybackBehavior.values,
        json['uncertain_behavior'],
        UncertainBuybackBehavior.suspected,
      ),
    );
  }

  final bool enabled;
  final bool buybackDetectionEnabled;
  final int baseProgress;
  final int matchDurationSeconds;
  final int timeDivisor;
  final int progressPenaltyPerBuyback;
  final int normalProgressPerSecond;
  final int acceleratedProgressPerSecond;
  final int lowBaseHealthThreshold;
  final int toleranceMilliseconds;
  final UncertainBuybackBehavior uncertainBehavior;

  /// 创建修改后的副本。
  RespawnRuleConfig copyWith({
    bool? enabled,
    bool? buybackDetectionEnabled,
    int? baseProgress,
    int? matchDurationSeconds,
    int? timeDivisor,
    int? progressPenaltyPerBuyback,
    int? normalProgressPerSecond,
    int? acceleratedProgressPerSecond,
    int? lowBaseHealthThreshold,
    int? toleranceMilliseconds,
    UncertainBuybackBehavior? uncertainBehavior,
  }) {
    return RespawnRuleConfig(
      enabled: enabled ?? this.enabled,
      buybackDetectionEnabled:
          buybackDetectionEnabled ?? this.buybackDetectionEnabled,
      baseProgress: (baseProgress ?? this.baseProgress).clamp(1, 300),
      matchDurationSeconds: (matchDurationSeconds ?? this.matchDurationSeconds)
          .clamp(60, 3600),
      timeDivisor: (timeDivisor ?? this.timeDivisor).clamp(1, 300),
      progressPenaltyPerBuyback:
          (progressPenaltyPerBuyback ?? this.progressPenaltyPerBuyback).clamp(
            0,
            300,
          ),
      normalProgressPerSecond:
          (normalProgressPerSecond ?? this.normalProgressPerSecond).clamp(
            1,
            20,
          ),
      acceleratedProgressPerSecond:
          (acceleratedProgressPerSecond ?? this.acceleratedProgressPerSecond)
              .clamp(1, 20),
      lowBaseHealthThreshold:
          (lowBaseHealthThreshold ?? this.lowBaseHealthThreshold).clamp(
            0,
            100000,
          ),
      toleranceMilliseconds:
          (toleranceMilliseconds ?? this.toleranceMilliseconds).clamp(0, 5000),
      uncertainBehavior: uncertainBehavior ?? this.uncertainBehavior,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'buyback_detection_enabled': buybackDetectionEnabled,
    'base_progress': baseProgress,
    'match_duration_seconds': matchDurationSeconds,
    'time_divisor': timeDivisor,
    'progress_penalty_per_buyback': progressPenaltyPerBuyback,
    'normal_progress_per_second': normalProgressPerSecond,
    'accelerated_progress_per_second': acceleratedProgressPerSecond,
    'low_base_health_threshold': lowBaseHealthThreshold,
    'tolerance_milliseconds': toleranceMilliseconds,
    'uncertain_behavior': uncertainBehavior.name,
  };
}

/// 英雄部署模式自动进入自定义图传的设置。
class DeploymentNavigationConfig {
  /// 创建部署跳转配置。
  const DeploymentNavigationConfig({
    this.enabled = true,
    this.countdownSeconds = 3,
    this.allowCancel = true,
    this.showEnterNow = true,
    this.prestartVideo = true,
    this.cancelForCurrentMatch = false,
    this.stayWhenVideoStartFails = true,
  });

  /// 从 JSON 创建配置。
  factory DeploymentNavigationConfig.fromJson(Map<String, dynamic> json) {
    return DeploymentNavigationConfig(
      enabled: _bool(json['enabled'], true),
      countdownSeconds: _boundedInt(json['countdown_seconds'], 3, 0, 10),
      allowCancel: _bool(json['allow_cancel'], true),
      showEnterNow: _bool(json['show_enter_now'], true),
      prestartVideo: _bool(json['prestart_video'], true),
      cancelForCurrentMatch: _bool(json['cancel_for_current_match'], false),
      stayWhenVideoStartFails: _bool(json['stay_when_video_start_fails'], true),
    );
  }

  final bool enabled;
  final int countdownSeconds;
  final bool allowCancel;
  final bool showEnterNow;
  final bool prestartVideo;
  final bool cancelForCurrentMatch;
  final bool stayWhenVideoStartFails;

  /// 创建修改后的副本。
  DeploymentNavigationConfig copyWith({
    bool? enabled,
    int? countdownSeconds,
    bool? allowCancel,
    bool? showEnterNow,
    bool? prestartVideo,
    bool? cancelForCurrentMatch,
    bool? stayWhenVideoStartFails,
  }) {
    return DeploymentNavigationConfig(
      enabled: enabled ?? this.enabled,
      countdownSeconds: (countdownSeconds ?? this.countdownSeconds).clamp(
        0,
        10,
      ),
      allowCancel: allowCancel ?? this.allowCancel,
      showEnterNow: showEnterNow ?? this.showEnterNow,
      prestartVideo: prestartVideo ?? this.prestartVideo,
      cancelForCurrentMatch:
          cancelForCurrentMatch ?? this.cancelForCurrentMatch,
      stayWhenVideoStartFails:
          stayWhenVideoStartFails ?? this.stayWhenVideoStartFails,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'countdown_seconds': countdownSeconds,
    'allow_cancel': allowCancel,
    'show_enter_now': showEnterNow,
    'prestart_video': prestartVideo,
    'cancel_for_current_match': cancelForCurrentMatch,
    'stay_when_video_start_fails': stayWhenVideoStartFails,
  };
}

/// MQTT、UDP 和自定义图传连接质量阈值。
class ConnectionQualityRuleConfig {
  /// 创建连接质量配置。
  const ConnectionQualityRuleConfig({
    this.mqttWarningSeconds = 2,
    this.mqttCriticalSeconds = 5,
    this.udpWindowSeconds = 5,
    this.udpWarningLossPercent = 5,
    this.udpCriticalLossPercent = 15,
    this.customVideoStaleSeconds = 2,
    this.decoderStaleSeconds = 3,
    this.recoveryStableSeconds = 3,
    this.debounceMilliseconds = 1000,
  });

  /// 从 JSON 创建配置。
  factory ConnectionQualityRuleConfig.fromJson(Map<String, dynamic> json) {
    final mqttWarning = _boundedInt(json['mqtt_warning_seconds'], 2, 1, 60);
    final udpWarning = _boundedInt(json['udp_warning_loss_percent'], 5, 0, 100);
    return ConnectionQualityRuleConfig(
      mqttWarningSeconds: mqttWarning,
      mqttCriticalSeconds: _boundedInt(
        json['mqtt_critical_seconds'],
        5,
        mqttWarning,
        120,
      ),
      udpWindowSeconds: _boundedInt(json['udp_window_seconds'], 5, 1, 60),
      udpWarningLossPercent: udpWarning,
      udpCriticalLossPercent: _boundedInt(
        json['udp_critical_loss_percent'],
        15,
        udpWarning,
        100,
      ),
      customVideoStaleSeconds: _boundedInt(
        json['custom_video_stale_seconds'],
        2,
        1,
        60,
      ),
      decoderStaleSeconds: _boundedInt(json['decoder_stale_seconds'], 3, 1, 60),
      recoveryStableSeconds: _boundedInt(
        json['recovery_stable_seconds'],
        3,
        1,
        60,
      ),
      debounceMilliseconds: _boundedInt(
        json['debounce_milliseconds'],
        1000,
        0,
        10000,
      ),
    );
  }

  final int mqttWarningSeconds;
  final int mqttCriticalSeconds;
  final int udpWindowSeconds;
  final int udpWarningLossPercent;
  final int udpCriticalLossPercent;
  final int customVideoStaleSeconds;
  final int decoderStaleSeconds;
  final int recoveryStableSeconds;
  final int debounceMilliseconds;

  /// 创建修改后的副本。
  ConnectionQualityRuleConfig copyWith({
    int? mqttWarningSeconds,
    int? mqttCriticalSeconds,
    int? udpWindowSeconds,
    int? udpWarningLossPercent,
    int? udpCriticalLossPercent,
    int? customVideoStaleSeconds,
    int? decoderStaleSeconds,
    int? recoveryStableSeconds,
    int? debounceMilliseconds,
  }) {
    final warning = (mqttWarningSeconds ?? this.mqttWarningSeconds).clamp(
      1,
      60,
    );
    final critical = (mqttCriticalSeconds ?? this.mqttCriticalSeconds).clamp(
      warning,
      120,
    );
    final udpWarning = (udpWarningLossPercent ?? this.udpWarningLossPercent)
        .clamp(0, 100);
    return ConnectionQualityRuleConfig(
      mqttWarningSeconds: warning,
      mqttCriticalSeconds: critical,
      udpWindowSeconds: (udpWindowSeconds ?? this.udpWindowSeconds).clamp(
        1,
        60,
      ),
      udpWarningLossPercent: udpWarning,
      udpCriticalLossPercent:
          (udpCriticalLossPercent ?? this.udpCriticalLossPercent).clamp(
            udpWarning,
            100,
          ),
      customVideoStaleSeconds:
          (customVideoStaleSeconds ?? this.customVideoStaleSeconds).clamp(
            1,
            60,
          ),
      decoderStaleSeconds: (decoderStaleSeconds ?? this.decoderStaleSeconds)
          .clamp(1, 60),
      recoveryStableSeconds:
          (recoveryStableSeconds ?? this.recoveryStableSeconds).clamp(1, 60),
      debounceMilliseconds: (debounceMilliseconds ?? this.debounceMilliseconds)
          .clamp(0, 10000),
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'mqtt_warning_seconds': mqttWarningSeconds,
    'mqtt_critical_seconds': mqttCriticalSeconds,
    'udp_window_seconds': udpWindowSeconds,
    'udp_warning_loss_percent': udpWarningLossPercent,
    'udp_critical_loss_percent': udpCriticalLossPercent,
    'custom_video_stale_seconds': customVideoStaleSeconds,
    'decoder_stale_seconds': decoderStaleSeconds,
    'recovery_stable_seconds': recoveryStableSeconds,
    'debounce_milliseconds': debounceMilliseconds,
  };
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

T _enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

int _boundedInt(Object? value, int fallback, int min, int max) {
  final parsed = value is num ? value.toInt() : fallback;
  return parsed.clamp(min, max);
}
