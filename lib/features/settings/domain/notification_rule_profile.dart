/// 可版本化的通知与比赛规则配置档案。
library;

import 'combat_notification_rules.dart';
import 'notification_preferences.dart';

/// 当前配置档案 JSON Schema 版本。
const int notificationProfileSchemaVersion = 1;

/// 内置官方配置档案 ID。
const String officialNotificationProfileId = 'official-rm2026-v1.3.1';

/// 内置通信协议版本。
const String officialProtocolVersion = '1.3.1';

/// 内置比赛规则版本。
const String officialRuleVersion = '1.5.0';

/// 单个通知与比赛规则档案。
class NotificationRuleProfile {
  /// 创建规则档案。
  const NotificationRuleProfile({
    required this.id,
    required this.name,
    required this.protocolVersion,
    required this.ruleVersion,
    required this.isOfficial,
    required this.display,
    required this.eventSettings,
    required this.killLine,
    required this.respawn,
    required this.deploymentNavigation,
    required this.connectionQuality,
    this.updatedAtIso,
  });

  /// 创建内置官方档案。
  factory NotificationRuleProfile.official() {
    return NotificationRuleProfile(
      id: officialNotificationProfileId,
      name: 'RoboMaster 2026 官方规则',
      protocolVersion: officialProtocolVersion,
      ruleVersion: officialRuleVersion,
      isOfficial: true,
      display: const NotificationDisplayConfig(),
      eventSettings: _defaultEventSettings(),
      killLine: const KillLineRuleConfig(),
      respawn: const RespawnRuleConfig(),
      deploymentNavigation: const DeploymentNavigationConfig(),
      connectionQuality: const ConnectionQualityRuleConfig(),
    );
  }

  /// 从 JSON 创建规则档案。
  factory NotificationRuleProfile.fromJson(Map<String, dynamic> json) {
    final schema = _int(
      json['schema_version'],
      notificationProfileSchemaVersion,
    );
    if (schema > notificationProfileSchemaVersion) {
      throw FormatException('Unsupported notification profile schema: $schema');
    }
    final defaults = NotificationRuleProfile.official();
    final eventsJson = _map(json['event_settings']);
    final parsedEvents = <NotificationEventType, NotificationEventSetting>{};
    for (final type in NotificationEventType.values) {
      final raw = _map(eventsJson[type.name]);
      parsedEvents[type] = raw.isEmpty
          ? defaults.eventSettings[type] ?? const NotificationEventSetting()
          : NotificationEventSetting.fromJson(raw);
    }
    return NotificationRuleProfile(
      id: _nonEmptyString(json['id'], _generatedProfileId()),
      name: _nonEmptyString(json['profile_name'], '导入的规则档案'),
      protocolVersion: _nonEmptyString(
        json['protocol_version'],
        officialProtocolVersion,
      ),
      ruleVersion: _nonEmptyString(json['rule_version'], officialRuleVersion),
      isOfficial: false,
      display: NotificationDisplayConfig.fromJson(_map(json['display'])),
      eventSettings: Map.unmodifiable(parsedEvents),
      killLine: KillLineRuleConfig.fromJson(_map(json['kill_line'])),
      respawn: RespawnRuleConfig.fromJson(_map(json['respawn'])),
      deploymentNavigation: DeploymentNavigationConfig.fromJson(
        _map(json['deployment_navigation']),
      ),
      connectionQuality: ConnectionQualityRuleConfig.fromJson(
        _map(json['connection_quality']),
      ),
      updatedAtIso: json['updated_at'] is String
          ? json['updated_at'] as String
          : null,
    );
  }

  final String id;
  final String name;
  final String protocolVersion;
  final String ruleVersion;
  final bool isOfficial;
  final NotificationDisplayConfig display;
  final Map<NotificationEventType, NotificationEventSetting> eventSettings;
  final KillLineRuleConfig killLine;
  final RespawnRuleConfig respawn;
  final DeploymentNavigationConfig deploymentNavigation;
  final ConnectionQualityRuleConfig connectionQuality;
  final String? updatedAtIso;

  /// 创建可编辑的自定义副本。
  NotificationRuleProfile customCopy({
    required String id,
    required String name,
  }) {
    return copyWith(
      id: id,
      name: name,
      isOfficial: false,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// 创建修改后的副本。
  NotificationRuleProfile copyWith({
    String? id,
    String? name,
    String? protocolVersion,
    String? ruleVersion,
    bool? isOfficial,
    NotificationDisplayConfig? display,
    Map<NotificationEventType, NotificationEventSetting>? eventSettings,
    KillLineRuleConfig? killLine,
    RespawnRuleConfig? respawn,
    DeploymentNavigationConfig? deploymentNavigation,
    ConnectionQualityRuleConfig? connectionQuality,
    String? updatedAtIso,
  }) {
    return NotificationRuleProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      ruleVersion: ruleVersion ?? this.ruleVersion,
      isOfficial: isOfficial ?? this.isOfficial,
      display: display ?? this.display,
      eventSettings: Map.unmodifiable(eventSettings ?? this.eventSettings),
      killLine: killLine ?? this.killLine,
      respawn: respawn ?? this.respawn,
      deploymentNavigation: deploymentNavigation ?? this.deploymentNavigation,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      updatedAtIso: updatedAtIso ?? this.updatedAtIso,
    );
  }

  /// 更新指定事件偏好。
  NotificationRuleProfile withEventSetting(
    NotificationEventType type,
    NotificationEventSetting setting,
  ) {
    return copyWith(eventSettings: {...eventSettings, type: setting});
  }

  /// 转换为可导出的 JSON。
  Map<String, dynamic> toJson() => {
    'schema_version': notificationProfileSchemaVersion,
    'id': id,
    'profile_name': name,
    'protocol_version': protocolVersion,
    'rule_version': ruleVersion,
    'is_official': isOfficial,
    'updated_at': updatedAtIso,
    'display': display.toJson(),
    'event_settings': {
      for (final entry in eventSettings.entries)
        entry.key.name: entry.value.toJson(),
    },
    'kill_line': killLine.toJson(),
    'respawn': respawn.toJson(),
    'deployment_navigation': deploymentNavigation.toJson(),
    'connection_quality': connectionQuality.toJson(),
  };
}

/// 所有档案和当前激活档案的持久化状态。
class NotificationProfileState {
  /// 创建档案状态。
  const NotificationProfileState({
    required this.profiles,
    required this.activeProfileId,
  });

  /// 创建仅包含官方档案的默认状态。
  factory NotificationProfileState.defaults() {
    final official = NotificationRuleProfile.official();
    return NotificationProfileState(
      profiles: [official],
      activeProfileId: official.id,
    );
  }

  /// 从 JSON 创建状态。
  factory NotificationProfileState.fromJson(Map<String, dynamic> json) {
    final profiles = <NotificationRuleProfile>[
      NotificationRuleProfile.official(),
    ];
    final rawProfiles = json['profiles'];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        final map = _map(raw);
        if (map.isEmpty || map['is_official'] == true) continue;
        try {
          profiles.add(NotificationRuleProfile.fromJson(map));
        } on FormatException {
          // 跳过不兼容档案，保留其余有效档案。
        }
      }
    }
    final requested = json['active_profile_id'];
    final activeId =
        requested is String && profiles.any((p) => p.id == requested)
        ? requested
        : officialNotificationProfileId;
    return NotificationProfileState(
      profiles: List.unmodifiable(profiles),
      activeProfileId: activeId,
    );
  }

  final List<NotificationRuleProfile> profiles;
  final String activeProfileId;

  /// 当前激活档案。
  NotificationRuleProfile get activeProfile => profiles.firstWhere(
    (profile) => profile.id == activeProfileId,
    orElse: NotificationRuleProfile.official,
  );

  /// 创建修改后的状态。
  NotificationProfileState copyWith({
    List<NotificationRuleProfile>? profiles,
    String? activeProfileId,
  }) {
    return NotificationProfileState(
      profiles: List.unmodifiable(profiles ?? this.profiles),
      activeProfileId: activeProfileId ?? this.activeProfileId,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() => {
    'schema_version': notificationProfileSchemaVersion,
    'active_profile_id': activeProfileId,
    'profiles': profiles.map((profile) => profile.toJson()).toList(),
  };
}

Map<NotificationEventType, NotificationEventSetting> _defaultEventSettings() {
  const critical = NotificationEventSetting(
    severity: NotificationSeverity.critical,
    requiresAcknowledgement: true,
  );
  const info = NotificationEventSetting();
  return Map.unmodifiable({
    for (final type in NotificationEventType.values)
      type: switch (type) {
        NotificationEventType.enemyRespawned ||
        NotificationEventType.enemyBoughtRespawn ||
        NotificationEventType.enemyKillLine ||
        NotificationEventType.enemyRequestedLevelFour ||
        NotificationEventType.moduleDisconnected => critical,
        _ => info,
      },
  });
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

int _int(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

String _nonEmptyString(Object? value, String fallback) {
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

String _generatedProfileId() =>
    'profile-${DateTime.now().microsecondsSinceEpoch}';
