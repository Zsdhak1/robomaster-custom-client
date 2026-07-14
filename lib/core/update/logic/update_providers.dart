/// 更新检查器使用的 Riverpod Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/installer_downloader.dart';
import '../data/update_checker_service.dart';
import '../data/version_comparator.dart';
import '../domain/github_release.dart';

// ============================================================
// 当前应用版本
// ============================================================

/// 提供当前应用版本字符串（`version+build`）。
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

// ============================================================
// 更新检查器服务
// ============================================================

/// 用于检查 GitHub Release 的服务实例。
final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  final service = UpdateCheckerService();
  ref.onDispose(service.dispose);
  return service;
});

// ============================================================
// 自动检查开关设置
// ============================================================

const _keyAutoCheckEnabled = 'update_auto_check_enabled';

/// 持久化启动时是否自动检查更新的通知器。
class AutoCheckEnabledNotifier extends StateNotifier<bool> {
  /// 创建通知器并加载已持久化的值。
  AutoCheckEnabledNotifier() : super(true) {
    _load();
  }

  /// 持久化 [enabled] 并更新状态。
  Future<void> set({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoCheckEnabled, enabled);
    state = enabled;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_keyAutoCheckEnabled) ?? true;
  }
}

/// 应用启动时是否自动检查更新。
final autoCheckEnabledProvider =
    StateNotifierProvider<AutoCheckEnabledNotifier, bool>(
  (ref) => AutoCheckEnabledNotifier(),
);

// ============================================================
// 更新检查结果
// ============================================================

/// 最近一次更新检查的结果。
final updateCheckResultProvider = FutureProvider<UpdateCheckResult>((ref) async {
  final current = await ref.watch(appVersionProvider.future);
  final service = ref.watch(updateCheckerServiceProvider);
  final result = await service.checkForUpdate();

  // 覆盖当前版本，因为服务本身可能没有拿到该值。
  if (result.currentVersion.isEmpty || result.currentVersion != current) {
    if (result.hasUpdate && result.release != null) {
      final hasUpdate = isNewerVersion(current, result.latestVersion);
      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        release: result.release,
        currentVersion: current,
        latestVersion: result.latestVersion,
      );
    }
    if (result.errorMessage != null) {
      return UpdateCheckResult.error(
        message: result.errorMessage!,
        currentVersion: current,
        isRateLimited: result.isRateLimited,
      );
    }
    return UpdateCheckResult.upToDate(
      currentVersion: current,
      latestVersion: result.latestVersion,
    );
  }
  return result;
});

/// 允许 UI 强制发起一次新的更新检查。
final manualUpdateCheckProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(updateCheckResultProvider);
});

// ============================================================
// 当前平台的最佳资源
// ============================================================

/// 当前平台最合适的安装包资源；没有时为 null。
final selectedAssetProvider = Provider<GitHubAsset?>((ref) {
  final result = ref.watch(updateCheckResultProvider);
  return result.whenOrNull(
    data: (r) => r.hasUpdate ? pickBestAsset(r.release!.assets) : null,
  );
});

// ============================================================
// 最后一次检查时间戳
// ============================================================

const _keyLastCheckTimestamp = 'update_last_check_timestamp';

/// 持久化最近一次成功或尝试过的更新检查时间戳。
Future<void> persistLastCheckTimestamp(DateTime timestamp) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyLastCheckTimestamp, timestamp.toIso8601String());
}

/// 读取已持久化的最近检查时间戳；没有时返回 null。
Future<DateTime?> readLastCheckTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyLastCheckTimestamp);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
