/// Riverpod providers for the update checker.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/installer_downloader.dart';
import '../data/update_checker_service.dart';
import '../data/version_comparator.dart';
import '../domain/github_release.dart';

// ============================================================
// Current app version
// ============================================================

/// Provides the current app version string (`version+build`).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version}+${info.buildNumber}';
});

// ============================================================
// Update checker service
// ============================================================

/// Service instance for checking GitHub releases.
final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  final service = UpdateCheckerService();
  ref.onDispose(service.dispose);
  return service;
});

// ============================================================
// Auto-check enabled setting
// ============================================================

const _keyAutoCheckEnabled = 'update_auto_check_enabled';

/// Notifier persisting whether update auto-check on startup is enabled.
class AutoCheckEnabledNotifier extends StateNotifier<bool> {
  /// Creates the notifier and loads the persisted value.
  AutoCheckEnabledNotifier() : super(true) {
    _load();
  }

  /// Persists [enabled] and updates state.
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

/// Whether the app should automatically check for updates on startup.
final autoCheckEnabledProvider =
    StateNotifierProvider<AutoCheckEnabledNotifier, bool>(
  (ref) => AutoCheckEnabledNotifier(),
);

// ============================================================
// Update check result
// ============================================================

/// Result of the latest update check.
final updateCheckResultProvider = FutureProvider<UpdateCheckResult>((ref) async {
  final current = await ref.watch(appVersionProvider.future);
  final service = ref.watch(updateCheckerServiceProvider);
  final result = await service.checkForUpdate();

  // Override the current version because the service may not have received it.
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

/// Allows the UI to force a fresh update check.
final manualUpdateCheckProvider = Provider<void Function()>((ref) {
  return () => ref.invalidate(updateCheckResultProvider);
});

// ============================================================
// Best asset for current platform
// ============================================================

/// The best installer asset for the current platform, or null.
final selectedAssetProvider = Provider<GitHubAsset?>((ref) {
  final result = ref.watch(updateCheckResultProvider);
  return result.whenOrNull(
    data: (r) => r.hasUpdate ? pickBestAsset(r.release!.assets) : null,
  );
});

// ============================================================
// Last check timestamp
// ============================================================

const _keyLastCheckTimestamp = 'update_last_check_timestamp';

/// Persists the timestamp of the last successful or attempted update check.
Future<void> persistLastCheckTimestamp(DateTime timestamp) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyLastCheckTimestamp, timestamp.toIso8601String());
}

/// Reads the persisted last-check timestamp, or null.
Future<DateTime?> readLastCheckTimestamp() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_keyLastCheckTimestamp);
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}
