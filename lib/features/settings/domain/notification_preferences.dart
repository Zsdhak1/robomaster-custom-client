/// 通知展示偏好与事件开关模型。
library;

/// 通知级别。
enum NotificationSeverity { info, critical }

/// 通知规则敏感度预设。
enum NotificationSensitivity { conservative, standard, sensitive }

/// 仪表盘通知显示位置。
enum NotificationPlacement { topBanner, rightCorner, sideBeacon }

/// CRITICAL 通知的关闭方式。
enum CriticalDismissMode { timed, acknowledgement, recovery }

/// 可单独配置的通知事件。
enum NotificationEventType {
  mqttDisconnected,
  mqttReconnected,
  connectionQualityChanged,
  allyAssemblyCompleted,
  allyRespawned,
  heroDeployAutoNavigation,
  enemyRespawned,
  enemyBoughtRespawn,
  enemyKillLine,
  enemyRequestedLevelFour,
  moduleDisconnected,
  moduleRecovered,
}

/// 单个通知事件的用户偏好。
class NotificationEventSetting {
  /// 创建事件偏好。
  const NotificationEventSetting({
    this.enabled = true,
    this.severity = NotificationSeverity.info,
    this.playSound = true,
    this.requiresAcknowledgement = false,
    this.cooldownSeconds = 5,
  });

  /// 从 JSON 创建事件偏好。
  factory NotificationEventSetting.fromJson(Map<String, dynamic> json) {
    return NotificationEventSetting(
      enabled: _bool(json['enabled'], true),
      severity: _enumValue(
        NotificationSeverity.values,
        json['severity'],
        NotificationSeverity.info,
      ),
      playSound: _bool(json['play_sound'], true),
      requiresAcknowledgement: _bool(json['requires_acknowledgement'], false),
      cooldownSeconds: _boundedInt(json['cooldown_seconds'], 5, 0, 300),
    );
  }

  /// 是否启用。
  final bool enabled;

  /// 通知级别。
  final NotificationSeverity severity;

  /// 是否播放提示音。
  final bool playSound;

  /// 是否要求用户确认。
  final bool requiresAcknowledgement;

  /// 相同通知的冷却时间。
  final int cooldownSeconds;

  /// 创建修改后的副本。
  NotificationEventSetting copyWith({
    bool? enabled,
    NotificationSeverity? severity,
    bool? playSound,
    bool? requiresAcknowledgement,
    int? cooldownSeconds,
  }) {
    return NotificationEventSetting(
      enabled: enabled ?? this.enabled,
      severity: severity ?? this.severity,
      playSound: playSound ?? this.playSound,
      requiresAcknowledgement:
          requiresAcknowledgement ?? this.requiresAcknowledgement,
      cooldownSeconds: (cooldownSeconds ?? this.cooldownSeconds).clamp(0, 300),
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'severity': severity.name,
    'play_sound': playSound,
    'requires_acknowledgement': requiresAcknowledgement,
    'cooldown_seconds': cooldownSeconds,
  };
}

/// 通知系统的全局展示偏好。
class NotificationDisplayConfig {
  /// 创建展示偏好。
  const NotificationDisplayConfig({
    this.enabled = true,
    this.sensitivity = NotificationSensitivity.standard,
    this.infoPlacement = NotificationPlacement.rightCorner,
    this.criticalPlacement = NotificationPlacement.topBanner,
    this.infoDurationSeconds = 5,
    this.criticalDurationSeconds = 10,
    this.maxVisibleInfo = 3,
    this.keepHistory = true,
    this.historyLimit = 50,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.muteWhenPaused = false,
    this.criticalDismissMode = CriticalDismissMode.acknowledgement,
  });

  /// 从 JSON 创建展示偏好。
  factory NotificationDisplayConfig.fromJson(Map<String, dynamic> json) {
    return NotificationDisplayConfig(
      enabled: _bool(json['enabled'], true),
      sensitivity: _enumValue(
        NotificationSensitivity.values,
        json['sensitivity'],
        NotificationSensitivity.standard,
      ),
      infoPlacement: _enumValue(
        NotificationPlacement.values,
        json['info_placement'],
        NotificationPlacement.rightCorner,
      ),
      criticalPlacement: _enumValue(
        NotificationPlacement.values,
        json['critical_placement'],
        NotificationPlacement.topBanner,
      ),
      infoDurationSeconds: _boundedInt(json['info_duration_seconds'], 5, 3, 15),
      criticalDurationSeconds: _boundedInt(
        json['critical_duration_seconds'],
        10,
        3,
        60,
      ),
      maxVisibleInfo: _boundedInt(json['max_visible_info'], 3, 1, 4),
      keepHistory: _bool(json['keep_history'], true),
      historyLimit: _boundedInt(json['history_limit'], 50, 10, 500),
      soundEnabled: _bool(json['sound_enabled'], true),
      vibrationEnabled: _bool(json['vibration_enabled'], true),
      muteWhenPaused: _bool(json['mute_when_paused'], false),
      criticalDismissMode: _enumValue(
        CriticalDismissMode.values,
        json['critical_dismiss_mode'],
        CriticalDismissMode.acknowledgement,
      ),
    );
  }

  final bool enabled;
  final NotificationSensitivity sensitivity;
  final NotificationPlacement infoPlacement;
  final NotificationPlacement criticalPlacement;
  final int infoDurationSeconds;
  final int criticalDurationSeconds;
  final int maxVisibleInfo;
  final bool keepHistory;
  final int historyLimit;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool muteWhenPaused;
  final CriticalDismissMode criticalDismissMode;

  /// 创建修改后的副本。
  NotificationDisplayConfig copyWith({
    bool? enabled,
    NotificationSensitivity? sensitivity,
    NotificationPlacement? infoPlacement,
    NotificationPlacement? criticalPlacement,
    int? infoDurationSeconds,
    int? criticalDurationSeconds,
    int? maxVisibleInfo,
    bool? keepHistory,
    int? historyLimit,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? muteWhenPaused,
    CriticalDismissMode? criticalDismissMode,
  }) {
    return NotificationDisplayConfig(
      enabled: enabled ?? this.enabled,
      sensitivity: sensitivity ?? this.sensitivity,
      infoPlacement: infoPlacement ?? this.infoPlacement,
      criticalPlacement: criticalPlacement ?? this.criticalPlacement,
      infoDurationSeconds: (infoDurationSeconds ?? this.infoDurationSeconds)
          .clamp(3, 15),
      criticalDurationSeconds:
          (criticalDurationSeconds ?? this.criticalDurationSeconds).clamp(
            3,
            60,
          ),
      maxVisibleInfo: (maxVisibleInfo ?? this.maxVisibleInfo).clamp(1, 4),
      keepHistory: keepHistory ?? this.keepHistory,
      historyLimit: (historyLimit ?? this.historyLimit).clamp(10, 500),
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      muteWhenPaused: muteWhenPaused ?? this.muteWhenPaused,
      criticalDismissMode: criticalDismissMode ?? this.criticalDismissMode,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'sensitivity': sensitivity.name,
    'info_placement': infoPlacement.name,
    'critical_placement': criticalPlacement.name,
    'info_duration_seconds': infoDurationSeconds,
    'critical_duration_seconds': criticalDurationSeconds,
    'max_visible_info': maxVisibleInfo,
    'keep_history': keepHistory,
    'history_limit': historyLimit,
    'sound_enabled': soundEnabled,
    'vibration_enabled': vibrationEnabled,
    'mute_when_paused': muteWhenPaused,
    'critical_dismiss_mode': criticalDismissMode.name,
  };
}

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

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;
