/// GitHub 远程同步配置的状态与持久化。
///
/// 保存 [RemoteSyncConfig]（仓库、分支、令牌、仓库内路径）并通过 SharedPreferences 持久化。
/// 访问令牌会保存在本地，避免用户每次启动都重新输入；它使用独立键存储，
/// 不会序列化进推送到仓库的共享 `record_config.json`。本地存储的信任边界是当前设备。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/github_sync_service.dart';
import '../../../core/sync/remote_sync_service.dart';
import 'settings_providers.dart';

/// SharedPreferences 中非敏感同步配置 JSON 使用的键。
const _keySyncConfig = 'github_sync_config';

/// SharedPreferences 中访问令牌使用的键；令牌与其余配置分开保存。
const _keySyncToken = 'github_sync_token';

/// 管理 [RemoteSyncConfig] 及其持久化的通知器。
class GitHubSyncConfigNotifier extends StateNotifier<RemoteSyncConfig> {
  /// 创建通知器并加载已持久化的配置。
  GitHubSyncConfigNotifier() : super(const RemoteSyncConfig()) {
    _load();
  }

  /// 替换并持久化配置；[RemoteSyncConfig.localRecordsDir] 是运行期字段，不参与持久化。
  Future<void> update(RemoteSyncConfig config) async {
    state = config;
    await _persist();
  }

  /// 只更新运行期本地下载目录，不写入持久化存储。
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
      // 持久化值已损坏：保留默认配置。
    }
  }
}

/// 当前 GitHub 同步配置。
final gitHubSyncConfigProvider =
    StateNotifierProvider<GitHubSyncConfigNotifier, RemoteSyncConfig>(
  (ref) => GitHubSyncConfigNotifier(),
);

/// 根据当前配置解析可用的 [RemoteSyncService]。
///
/// 配置了仓库后返回 [GitHubSyncService]（公开仓库拉取无需令牌），否则返回本地
/// [NoopRemoteSyncService]。本地导出目录会附加到配置中，供下载记录落盘使用。
final gitHubBackedSyncServiceProvider = Provider<RemoteSyncService>((ref) {
  final config = ref.watch(gitHubSyncConfigProvider);
  final exportDir = ref.watch(exportDirectoryProvider);
  final effectiveConfig = config.copyWith(localRecordsDir: exportDir);
  if (!effectiveConfig.canPull) return const NoopRemoteSyncService();
  final service = GitHubSyncService(config: effectiveConfig);
  ref.onDispose(service.dispose);
  return service;
});
