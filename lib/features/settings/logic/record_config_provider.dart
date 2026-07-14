/// 记录配置：声明客户端需要订阅并保存哪些协议 topic。
///
/// 配置通过 SharedPreferences 本地持久化，JSON 序列化结构与共享的
/// `record_config.json` Schema 保持一致，后续 GitHub 同步可以直接接入而不改变通知器 API。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/topic_registry.dart';
import '../../../core/sync/remote_sync_service.dart';

/// SharedPreferences 中保存已启用 topic 集合 JSON 的键。
const _keyRecordConfig = 'record_config_enabled_topics';

/// `record_config.json` 载荷的 Schema 版本，用于向前兼容。
const int recordConfigSchemaVersion = 1;

/// 客户端应该订阅并记录的不可变 topic 集合。
class RecordConfig {
  /// 使用显式的 [enabledTopics] 集合创建 [RecordConfig]。
  const RecordConfig({required this.enabledTopics});

  /// 默认配置：启用每个可记录的服务器到客户端 topic。
  RecordConfig.allEnabled()
      : enabledTopics = Set.unmodifiable(TopicRegistry.recordableTopicNames);

  /// 已启用的 topic 名称集合；始终是可记录 topic 的子集。
  final Set<String> enabledTopics;

  /// 判断 [topic] 是否已启用记录。
  bool isEnabled(String topic) => enabledTopics.contains(topic);

  /// 返回将 [topic] 切换为 [enabled] 后的新配置。
  RecordConfig withTopic(String topic, {required bool enabled}) {
    final next = Set<String>.from(enabledTopics);
    if (enabled) {
      next.add(topic);
    } else {
      next.remove(topic);
    }
    return RecordConfig(enabledTopics: next);
  }

  /// 返回启用或禁用所有可记录 topic 后的新配置。
  RecordConfig withAll({required bool enabled}) {
    return RecordConfig(
      enabledTopics:
          enabled ? Set.from(TopicRegistry.recordableTopicNames) : <String>{},
    );
  }

  /// 从共享 JSON Schema 解析 [RecordConfig]。
///
  /// 未知 topic 名称会被丢弃以保持向前兼容；缺失或无效输入会回退到
  /// [RecordConfig.allEnabled]。
  factory RecordConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['enabled_topics'];
    if (raw is! List) return RecordConfig.allEnabled();
    final valid = raw
        .whereType<String>()
        .where(TopicRegistry.recordableTopicNames.contains)
        .toSet();
    if (valid.isEmpty) return RecordConfig.allEnabled();
    return RecordConfig(enabledTopics: valid);
  }

  /// 序列化为共享 JSON Schema，供本地持久化和后续 `record_config.json` push/pull 使用。
  Map<String, dynamic> toJson() => {
        'schema_version': recordConfigSchemaVersion,
        'enabled_topics': enabledTopics.toList()..sort(),
      };
}

/// 管理 [RecordConfig]，负责本地持久化，并通过 [RemoteSyncService] 拉取共享配置。
class RecordConfigNotifier extends StateNotifier<RecordConfig> {
  /// 创建通知器并加载已持久化的配置。
  RecordConfigNotifier({RemoteSyncService? remote})
      : _remote = remote ?? const NoopRemoteSyncService(),
        super(RecordConfig.allEnabled()) {
    _load();
  }

  final RemoteSyncService _remote;

  /// 启用或禁用单个 [topic]，并立即持久化。
  Future<void> setTopic(String topic, {required bool enabled}) async {
    state = state.withTopic(topic, enabled: enabled);
    await _persist();
  }

  /// 启用或禁用每个可记录 topic，并立即持久化。
  Future<void> setAll({required bool enabled}) async {
    state = state.withAll(enabled: enabled);
    await _persist();
  }

  /// 替换整个配置并持久化，供远程同步或导入流程使用。
  Future<void> replace(RecordConfig config) async {
    state = config;
    await _persist();
  }

  /// 从远程存储拉取共享配置并应用到本地状态。
///
  /// 返回 [SyncResult]。当前空操作远程服务会报告“未配置”；接入 GitHub 实现后，
  /// 调用方无需修改即可获得实际同步能力。
  Future<SyncResult> pullFromRemote() async {
    final json = await _remote.pullRecordConfig();
    if (json == null) {
      return SyncResult.failure('未能从远程获取配置（远程同步未配置）');
    }
    await replace(RecordConfig.fromJson(json));
    return SyncResult.success('已从远程同步记录配置');
  }

  /// 将当前配置推送到远程共享位置。
  Future<SyncResult> pushToRemote() => _remote.pushRecordConfig(state.toJson());

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRecordConfig, jsonEncode(state.toJson()));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRecordConfig);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = RecordConfig.fromJson(decoded);
      }
    } on FormatException {
      // 持久化值已损坏：保留默认的全启用配置。
    }
  }
}

/// 可注入的远程同步服务；测试或接入 GitHub 后端时可覆盖，默认使用本地空操作实现。
final remoteSyncServiceProvider = Provider<RemoteSyncService>(
  (ref) => const NoopRemoteSyncService(),
);

/// 当前记录配置，即需要订阅并保存的 topic 集合。
final recordConfigProvider =
    StateNotifierProvider<RecordConfigNotifier, RecordConfig>(
  (ref) => RecordConfigNotifier(remote: ref.watch(remoteSyncServiceProvider)),
);
