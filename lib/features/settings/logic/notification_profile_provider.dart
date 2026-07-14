/// 通知与比赛规则配置档案的持久化 Provider。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/combat_notification_rules.dart';
import '../domain/notification_preferences.dart';
import '../domain/notification_rule_profile.dart';

const String _notificationProfilesPreferencesKey = 'notification_rule_profiles';

/// 管理规则档案、当前选择和持久化。
class NotificationProfileNotifier
    extends StateNotifier<NotificationProfileState> {
  /// 创建通知器并加载本地档案。
  NotificationProfileNotifier() : super(NotificationProfileState.defaults()) {
    unawaited(_load());
  }

  final Completer<void> _loaded = Completer<void>();

  /// 初次持久化加载完成。
  Future<void> get loaded => _loaded.future;

  /// 切换当前档案。
  Future<void> activate(String profileId) async {
    if (!state.profiles.any((profile) => profile.id == profileId)) return;
    state = state.copyWith(activeProfileId: profileId);
    await _save();
  }

  /// 复制当前档案并激活新的可编辑档案。
  Future<NotificationRuleProfile> duplicateActive({String? name}) async {
    final source = state.activeProfile;
    final id = _uniqueId();
    final trimmedName = name?.trim();
    final copy = source.customCopy(
      id: id,
      name: trimmedName?.isNotEmpty == true
          ? trimmedName ?? source.name
          : '${source.name} 副本',
    );
    state = state.copyWith(
      profiles: [...state.profiles, copy],
      activeProfileId: copy.id,
    );
    await _save();
    return copy;
  }

  /// 导入一个外部档案并激活。
  Future<NotificationRuleProfile> addImported(
    NotificationRuleProfile imported,
  ) async {
    final profile = imported.copyWith(
      id: _uniqueId(),
      isOfficial: false,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    state = state.copyWith(
      profiles: [...state.profiles, profile],
      activeProfileId: profile.id,
    );
    await _save();
    return profile;
  }

  /// 从 JSON 文本导入档案。
  Future<NotificationRuleProfile> importJson(String encoded) async {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Notification profile must be a JSON object');
    }
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    return addImported(NotificationRuleProfile.fromJson(map));
  }

  /// 导出当前档案的格式化 JSON。
  String exportActiveJson() =>
      const JsonEncoder.withIndent('  ').convert(state.activeProfile.toJson());

  /// 更新当前档案的展示偏好。
  Future<void> updateDisplay(NotificationDisplayConfig config) =>
      _updateActive((profile) => profile.copyWith(display: config));

  /// 更新当前档案的单个事件偏好。
  Future<void> updateEvent(
    NotificationEventType type,
    NotificationEventSetting setting,
  ) => _updateActive((profile) => profile.withEventSetting(type, setting));

  /// 更新斩杀线规则。
  Future<void> updateKillLine(KillLineRuleConfig config) =>
      _updateActive((profile) => profile.copyWith(killLine: config));

  /// 更新复活规则。
  Future<void> updateRespawn(RespawnRuleConfig config) =>
      _updateActive((profile) => profile.copyWith(respawn: config));

  /// 更新部署跳转规则。
  Future<void> updateDeploymentNavigation(DeploymentNavigationConfig config) =>
      _updateActive(
        (profile) => profile.copyWith(deploymentNavigation: config),
      );

  /// 更新连接质量规则。
  Future<void> updateConnectionQuality(ConnectionQualityRuleConfig config) =>
      _updateActive((profile) => profile.copyWith(connectionQuality: config));

  /// 将当前自定义档案恢复为官方默认参数，保留档案名称和 ID。
  Future<void> resetActive() async {
    final active = state.activeProfile;
    if (active.isOfficial) return;
    final defaults = NotificationRuleProfile.official();
    await _replaceActive(
      defaults.copyWith(
        id: active.id,
        name: active.name,
        isOfficial: false,
        updatedAtIso: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// 删除自定义档案；官方档案不可删除。
  Future<void> remove(String profileId) async {
    final target = state.profiles.where((profile) => profile.id == profileId);
    if (target.isEmpty || target.first.isOfficial) return;
    final profiles = state.profiles
        .where((profile) => profile.id != profileId)
        .toList(growable: false);
    final activeId = state.activeProfileId == profileId
        ? officialNotificationProfileId
        : state.activeProfileId;
    state = state.copyWith(profiles: profiles, activeProfileId: activeId);
    await _save();
  }

  Future<void> _updateActive(
    NotificationRuleProfile Function(NotificationRuleProfile profile) update,
  ) async {
    final active = state.activeProfile;
    if (active.isOfficial) return;
    final updated = update(
      active,
    ).copyWith(updatedAtIso: DateTime.now().toUtc().toIso8601String());
    await _replaceActive(updated);
  }

  Future<void> _replaceActive(NotificationRuleProfile replacement) async {
    final profiles = [
      for (final profile in state.profiles)
        if (profile.id == state.activeProfileId) replacement else profile,
    ];
    state = state.copyWith(profiles: profiles);
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_notificationProfilesPreferencesKey);
      if (encoded == null) return;
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        state = NotificationProfileState.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } on Object {
      state = NotificationProfileState.defaults();
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notificationProfilesPreferencesKey,
      jsonEncode(state.toJson()),
    );
  }

  String _uniqueId() => 'profile-${DateTime.now().microsecondsSinceEpoch}';
}

/// 所有通知规则档案及当前档案。
final notificationProfileProvider =
    StateNotifierProvider<
      NotificationProfileNotifier,
      NotificationProfileState
    >((ref) => NotificationProfileNotifier());

/// 当前激活的通知规则档案。
final activeNotificationProfileProvider = Provider<NotificationRuleProfile>(
  (ref) => ref.watch(notificationProfileProvider).activeProfile,
);
