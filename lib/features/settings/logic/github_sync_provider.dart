/// State + persistence for the GitHub remote-sync configuration.
///
/// Holds a [RemoteSyncConfig] (repository, branch, token, in-repo paths) and
/// persists it via SharedPreferences. The access token IS persisted locally so
/// the user does not re-enter it every launch; it is stored under a dedicated
/// key and never serialized into the shared `record_config.json` that gets
/// pushed to the repo. Treat the local store as device-trust scoped.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/github_sync_service.dart';
import '../../../core/sync/remote_sync_service.dart';
import 'settings_providers.dart';

/// SharedPreferences key for the non-secret sync config JSON.
const _keySyncConfig = 'github_sync_config';

/// SharedPreferences key for the access token (kept separate from the rest).
const _keySyncToken = 'github_sync_token';

/// Notifier owning the [RemoteSyncConfig] and its persistence.
class GitHubSyncConfigNotifier extends StateNotifier<RemoteSyncConfig> {
  /// Creates the notifier and loads any persisted config.
  GitHubSyncConfigNotifier() : super(const RemoteSyncConfig()) {
    _load();
  }

  /// Replaces the config (except [RemoteSyncConfig.localRecordsDir], which is a
  /// runtime-only field) and persists.
  Future<void> update(RemoteSyncConfig config) async {
    state = config;
    await _persist();
  }

  /// Updates only the runtime local download directory (not persisted).
  void setLocalRecordsDir(String dir) {
    state = state.copyWith(localRecordsDir: dir);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySyncConfig, jsonEncode(state.toJson()));
    if (state.token.isEmpty) {
      await prefs.remove(_keySyncToken);
    } else {
      await prefs.setString(_keySyncToken, state.token);
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySyncConfig);
    final token = prefs.getString(_keySyncToken) ?? '';
    if (raw == null || raw.isEmpty) {
      if (token.isNotEmpty) state = state.copyWith(token: token);
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = RemoteSyncConfig.fromJson(decoded).copyWith(token: token);
      }
    } on FormatException {
      // Corrupt persisted value: keep defaults.
    }
  }
}

/// The current GitHub sync configuration.
final gitHubSyncConfigProvider =
    StateNotifierProvider<GitHubSyncConfigNotifier, RemoteSyncConfig>(
  (ref) => GitHubSyncConfigNotifier(),
);

/// Resolves the active [RemoteSyncService] from the current config.
///
/// Returns a [GitHubSyncService] once a repository is set (public pulls need no
/// token), otherwise the local [NoopRemoteSyncService]. The local export
/// directory is attached so downloads know where to land.
final gitHubBackedSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  final config = ref.watch(gitHubSyncConfigProvider);
  final exportDir = ref.watch(exportDirectoryProvider);
  final effectiveConfig = config.copyWith(localRecordsDir: exportDir);
  if (!effectiveConfig.canPull) return const NoopRemoteSyncService();
  final service = GitHubSyncService(config: effectiveConfig);
  ref.onDispose(service.dispose);
  return service;
});
