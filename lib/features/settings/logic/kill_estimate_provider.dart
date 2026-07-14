/// 击杀估算配置的 Riverpod 持久化 Provider。
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/kill_estimate_config.dart';

const String _killEstimatePreferencesKey = 'kill_estimate_config';

/// 管理并持久化 [KillEstimateConfig]。
class KillEstimateConfigNotifier extends StateNotifier<KillEstimateConfig> {
  /// 创建通知器并异步加载已保存配置。
  KillEstimateConfigNotifier() : super(const KillEstimateConfig()) {
    _load();
  }

  /// 保存完整配置。
  Future<void> setConfig(KillEstimateConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _killEstimatePreferencesKey,
      jsonEncode(config.toJson()),
    );
    state = config;
  }

  /// 恢复默认配置。
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_killEstimatePreferencesKey);
    state = const KillEstimateConfig();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_killEstimatePreferencesKey);
      if (encoded == null) return;
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) {
        state = KillEstimateConfig.fromJson(decoded);
      }
    } on Object {
      state = const KillEstimateConfig();
    }
  }
}

/// 当前击杀估算配置。
final killEstimateConfigProvider =
    StateNotifierProvider<KillEstimateConfigNotifier, KillEstimateConfig>(
      (ref) => KillEstimateConfigNotifier(),
    );
