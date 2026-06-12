/// Record configuration: which protocol topics the client subscribes to and
/// records. Persisted locally via SharedPreferences, with JSON
/// (de)serialization that matches the shared `record_config.json` schema so a
/// future GitHub sync can swap in without changing this notifier's API.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/topic_registry.dart';
import '../../../core/sync/remote_sync_service.dart';

/// SharedPreferences key holding the JSON-encoded enabled-topic set.
const _keyRecordConfig = 'record_config_enabled_topics';

/// Schema version of the `record_config.json` payload, for forward-compat.
const int recordConfigSchemaVersion = 1;

/// Immutable set of topics the client should subscribe to and record.
class RecordConfig {
  /// Creates a [RecordConfig] from an explicit [enabledTopics] set.
  const RecordConfig({required this.enabledTopics});

  /// Default config: every recordable (server→client) topic enabled.
  RecordConfig.allEnabled()
      : enabledTopics = Set.unmodifiable(TopicRegistry.recordableTopicNames);

  /// The set of enabled topic names. Always a subset of recordable topics.
  final Set<String> enabledTopics;

  /// Whether [topic] is enabled for recording.
  bool isEnabled(String topic) => enabledTopics.contains(topic);

  /// Returns a copy with [topic] toggled to [enabled].
  RecordConfig withTopic(String topic, {required bool enabled}) {
    final next = Set<String>.from(enabledTopics);
    if (enabled) {
      next.add(topic);
    } else {
      next.remove(topic);
    }
    return RecordConfig(enabledTopics: next);
  }

  /// Returns a copy with all recordable topics enabled or disabled.
  RecordConfig withAll({required bool enabled}) {
    return RecordConfig(
      enabledTopics:
          enabled ? Set.from(TopicRegistry.recordableTopicNames) : <String>{},
    );
  }

  /// Parses a [RecordConfig] from the shared JSON schema.
  ///
  /// Unknown topic names are dropped (forward-compat); missing/invalid input
  /// falls back to [RecordConfig.allEnabled].
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

  /// Serializes to the shared JSON schema (used for local persistence and the
  /// future `record_config.json` push/pull).
  Map<String, dynamic> toJson() => {
        'schema_version': recordConfigSchemaVersion,
        'enabled_topics': enabledTopics.toList()..sort(),
      };
}

/// Notifier managing [RecordConfig] with local persistence and a hook for
/// pulling a shared config from a [RemoteSyncService].
class RecordConfigNotifier extends StateNotifier<RecordConfig> {
  /// Creates the notifier and loads the persisted config.
  RecordConfigNotifier({RemoteSyncService? remote})
      : _remote = remote ?? const NoopRemoteSyncService(),
        super(RecordConfig.allEnabled()) {
    _load();
  }

  final RemoteSyncService _remote;

  /// Enables or disables a single [topic] and persists.
  Future<void> setTopic(String topic, {required bool enabled}) async {
    state = state.withTopic(topic, enabled: enabled);
    await _persist();
  }

  /// Enables or disables every recordable topic and persists.
  Future<void> setAll({required bool enabled}) async {
    state = state.withAll(enabled: enabled);
    await _persist();
  }

  /// Replaces the whole config and persists (used by remote sync / import).
  Future<void> replace(RecordConfig config) async {
    state = config;
    await _persist();
  }

  /// Pulls the shared config from the remote store and applies it.
  ///
  /// Returns a [SyncResult]. With the current no-op remote this always reports
  /// "not configured"; the GitHub implementation will make it functional with
  /// no change to callers.
  Future<SyncResult> pullFromRemote() async {
    final json = await _remote.pullRecordConfig();
    if (json == null) {
      return SyncResult.failure('未能从远程获取配置（远程同步未配置）');
    }
    await replace(RecordConfig.fromJson(json));
    return SyncResult.success('已从远程同步记录配置');
  }

  /// Pushes the current config to the remote shared location.
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
      // Corrupt persisted value: keep the default all-enabled config.
    }
  }
}

/// Injectable remote sync service. Overridden in tests or when the GitHub
/// backend is wired; defaults to the local no-op.
final remoteSyncServiceProvider = Provider<RemoteSyncService>(
  (ref) => const NoopRemoteSyncService(),
);

/// The active record configuration (which topics to subscribe/record).
final recordConfigProvider =
    StateNotifierProvider<RecordConfigNotifier, RecordConfig>(
  (ref) => RecordConfigNotifier(remote: ref.watch(remoteSyncServiceProvider)),
);
