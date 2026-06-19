/// Settings-related Riverpod providers with SharedPreferences persistence.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data_export/data/default_export_directory.dart';

// ============================================================
// Theme mode — light / dark / follow system
// ============================================================

const _keyThemeMode = 'theme_mode';

/// Notifier persisting the app [ThemeMode] (default: follow system).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// Creates the notifier and loads the persisted value.
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  /// Persists [mode] by its index and updates state.
  Future<void> set(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeMode, mode.index);
    state = mode;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyThemeMode);
    if (index != null && index >= 0 && index < ThemeMode.values.length) {
      state = ThemeMode.values[index];
    }
  }
}

/// The user's chosen theme mode (light / dark / system).
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

// ============================================================
// Video decoder backend
// ============================================================

/// Available video decoder backends that the user can choose between.
enum VideoDecoderBackend {
  /// media_kit — libmpv based, robust across platforms.
  mediaKit,

  /// fvp — libmdk based, lower latency.
  fvp,

  /// ffplay subprocess (Windows) — forces `-f hevc`, renders in own window.
  ffplay,
}

/// Human-readable label for a [VideoDecoderBackend].
extension VideoDecoderBackendLabel on VideoDecoderBackend {
  /// Short Chinese label.
  String get label => switch (this) {
        VideoDecoderBackend.mediaKit => 'media_kit',
        VideoDecoderBackend.fvp => 'fvp',
        VideoDecoderBackend.ffplay => 'ffplay (验证)',
      };

  /// One-line description.
  String get description => switch (this) {
        VideoDecoderBackend.mediaKit =>
          '基于 libmpv，全平台兼容好，硬/软解自适应',
        VideoDecoderBackend.fvp =>
          '基于 libmdk，延迟更低，体积小一些',
        VideoDecoderBackend.ffplay =>
          '仅 Windows：调用 ffplay 子进程，强制 hevc 格式，独立窗口播放，用于验证拼包',
      };
}

// ============================================================
// SharedPreferences key
// ============================================================

const _keyDecoderBackend = 'video_decoder_backend';
const _keyCustomVideoBackend = 'custom_video_decoder_backend';

// ============================================================
// Notifier
// ============================================================

/// Notifier that reads/writes a decoder backend via SharedPreferences.
///
/// Parameterised by [_prefsKey] and [_fallback] so the official UDP line and
/// the custom 0x0310 H.264 line each get an independent, separately persisted
/// backend choice from the same implementation.
class VideoDecoderBackendNotifier extends StateNotifier<VideoDecoderBackend> {
  /// Creates the notifier and loads the persisted value.
  VideoDecoderBackendNotifier({
    required this._prefsKey,
    VideoDecoderBackend fallback = VideoDecoderBackend.mediaKit,
  })  : _fallback = fallback,
        super(fallback) {
    _load();
  }

  final String _prefsKey;
  final VideoDecoderBackend _fallback;

  /// Persists [backend] to SharedPreferences and updates state.
  Future<void> set(VideoDecoderBackend backend) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, backend.index);
    state = backend;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_prefsKey);
    if (index != null && index >= 0 && index < VideoDecoderBackend.values.length) {
      state = VideoDecoderBackend.values[index];
    } else {
      state = _fallback;
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// The user's chosen video decoder backend for the official UDP 3334 line.
final videoDecoderBackendProvider =
    StateNotifierProvider<VideoDecoderBackendNotifier, VideoDecoderBackend>(
  (ref) => VideoDecoderBackendNotifier(prefsKey: _keyDecoderBackend),
);

/// The user's chosen decoder backend for the custom 0x0310 H.264 line.
///
/// Independent of [videoDecoderBackendProvider] so the raw-H.264 custom feed
/// can be A/B tested (fvp vs media_kit) or verified with external ffplay
/// without disturbing the official HEVC line. Defaults to fvp — the only
/// in-app backend that ships a raw-H.264 demuxer on desktop.
final customVideoBackendProvider =
    StateNotifierProvider<VideoDecoderBackendNotifier, VideoDecoderBackend>(
  (ref) => VideoDecoderBackendNotifier(
    prefsKey: _keyCustomVideoBackend,
    fallback: VideoDecoderBackend.fvp,
  ),
);

// ============================================================
// Hardware decoder (libmpv `hwdec`) — applies to the media_kit backend
// ============================================================

/// libmpv `hwdec` modes. The [value] is passed verbatim to mpv's `hwdec`
/// property; an unsupported choice makes mpv fall back to software decoding.
///
/// Covers the platforms this app targets (Android / Windows / Linux) plus the
/// common cross-platform options.
enum HwdecMode {
  /// Enable any available decoder.
  auto('auto', 'auto', '启用任意可用解码器'),

  /// Enable the best whitelisted decoder (recommended default).
  autoSafe('auto-safe', 'auto-safe', '启用最佳解码器（推荐）'),

  /// Best decoder with read-back copy to system memory.
  autoCopy('auto-copy', 'auto-copy', '启用带拷贝功能的最佳解码器'),

  /// Force software decoding.
  none('no', 'no', '关闭硬件解码，强制软件解码'),

  /// DirectX 11 video acceleration (Windows 8+).
  d3d11va('d3d11va', 'd3d11va', 'DirectX11 (Windows8 及以上)'),

  /// DirectX 11 video acceleration, non-zero-copy.
  d3d11vaCopy('d3d11va-copy', 'd3d11va-copy', 'DirectX11 (Windows8 及以上) (非直通)'),

  /// DirectX 9 video acceleration (Windows 7+).
  dxva2('dxva2', 'dxva2', 'DXVA2 (Windows7 及以上)'),

  /// DirectX 9 video acceleration, non-zero-copy.
  dxva2Copy('dxva2-copy', 'dxva2-copy', 'DXVA2 (Windows7 及以上) (非直通)'),

  /// Android MediaCodec hardware decoder.
  mediacodec('mediacodec', 'mediacodec', 'MediaCodec (Android)'),

  /// Android MediaCodec, non-zero-copy.
  mediacodecCopy('mediacodec-copy', 'mediacodec-copy', 'MediaCodec (Android) (非直通)'),

  /// VA-API hardware decoder (Linux).
  vaapi('vaapi', 'vaapi', 'VAAPI (Linux)'),

  /// VA-API, non-zero-copy.
  vaapiCopy('vaapi-copy', 'vaapi-copy', 'VAAPI (Linux) (非直通)'),

  /// NVIDIA NVDEC hardware decoder.
  nvdec('nvdec', 'nvdec', 'NVDEC (NVIDIA 独占)'),

  /// NVIDIA NVDEC, non-zero-copy.
  nvdecCopy('nvdec-copy', 'nvdec-copy', 'NVDEC (NVIDIA 独占) (非直通)'),

  /// DRM hardware decoder (Linux).
  drm('drm', 'drm', 'DRM (Linux)'),

  /// DRM, non-zero-copy.
  drmCopy('drm-copy', 'drm-copy', 'DRM (Linux) (非直通)'),

  /// VideoToolbox hardware decoder (macOS / iOS).
  videotoolbox('videotoolbox', 'videotoolbox', 'VideoToolbox (macOS / iOS)'),

  /// VideoToolbox, non-zero-copy.
  videotoolboxCopy(
      'videotoolbox-copy', 'videotoolbox-copy', 'VideoToolbox (macOS / iOS) (非直通)'),

  /// Vulkan hardware decoder (experimental, cross-platform).
  vulkan('vulkan', 'vulkan', 'Vulkan (全平台) (实验性)'),

  /// Vulkan, non-zero-copy.
  vulkanCopy('vulkan-copy', 'vulkan-copy', 'Vulkan (全平台) (实验性) (非直通)');

  const HwdecMode(this.value, this.label, this.description);

  /// The exact string passed to mpv's `hwdec` property.
  final String value;

  /// Short label shown in the picker.
  final String label;

  /// One-line Chinese description.
  final String description;

  /// Resolves a persisted [value] back to an enum, defaulting to [autoSafe].
  static HwdecMode fromValue(String? v) {
    for (final m in HwdecMode.values) {
      if (m.value == v) return m;
    }
    return HwdecMode.autoSafe;
  }
}

const _keyHwdec = 'video_hwdec_mode';

/// Notifier persisting the chosen [HwdecMode] by its mpv string value.
class HwdecModeNotifier extends StateNotifier<HwdecMode> {
  /// Creates the notifier and loads the persisted value.
  HwdecModeNotifier() : super(HwdecMode.autoSafe) {
    _load();
  }

  /// Persists [mode] and updates state.
  Future<void> set(HwdecMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHwdec, mode.value);
    state = mode;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = HwdecMode.fromValue(prefs.getString(_keyHwdec));
  }
}

/// The user's chosen libmpv hardware-decoder mode.
final hwdecModeProvider =
    StateNotifierProvider<HwdecModeNotifier, HwdecMode>(
  (ref) => HwdecModeNotifier(),
);

// ============================================================
// Developer mode — toggles visibility of all debug components
// ============================================================

const _keyDeveloperMode = 'developer_mode';

/// Notifier persisting the developer-mode flag (default off).
class DeveloperModeNotifier extends StateNotifier<bool> {
  /// Creates the notifier and loads the persisted value.
  DeveloperModeNotifier() : super(false) {
    _load();
  }

  /// Persists [enabled] and updates state.
  Future<void> set({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDeveloperMode, enabled);
    state = enabled;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_keyDeveloperMode) ?? false;
  }
}

/// Whether developer mode is on. When off, all debug components are hidden.
final developerModeProvider =
    StateNotifierProvider<DeveloperModeNotifier, bool>(
  (ref) => DeveloperModeNotifier(),
);

// ============================================================
// Custom video MPEG-TS wrapping
// ============================================================

const _keyCustomVideoTsWrap = 'custom_video_ts_wrap';

/// Notifier persisting whether the custom 0x0310 line is wrapped in MPEG-TS.
class CustomVideoTsWrapNotifier extends StateNotifier<bool> {
  /// Creates the notifier and loads the persisted value (default off).
  CustomVideoTsWrapNotifier() : super(false) {
    _load();
  }

  /// Persists [enabled] and updates state.
  Future<void> set({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCustomVideoTsWrap, enabled);
    state = enabled;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_keyCustomVideoTsWrap) ?? false;
  }
}

/// Whether the custom H.264 line is wrapped in MPEG-TS before serving.
///
/// Off → the bridge serves raw Annex-B (fvp on Linux can decode it). On → the
/// bridge serves MPEG-TS, which media_kit's libmpv CAN demux (its raw-H.264
/// demuxer is missing), unblocking media_kit on Windows where fvp cannot
/// render. Both in-app players switch their forced demuxer format accordingly.
final customVideoTsWrapProvider =
    StateNotifierProvider<CustomVideoTsWrapNotifier, bool>(
  (ref) => CustomVideoTsWrapNotifier(),
);

// ============================================================
// Export directory — where JSON exports are saved
// ============================================================

const _keyExportDirectory = 'export_directory';

/// Notifier persisting the JSON export directory path.
///
/// On first run (no user-chosen path) it falls back to the per-platform
/// default directory resolved via [resolveDefaultExportDirectory], so that
/// automatic recording and saving works without any manual setup. A user
/// selection persists and takes precedence; [resetToDefault] returns to the
/// platform default.
class ExportDirectoryNotifier extends StateNotifier<String> {
  /// Creates the notifier and loads the persisted or default path.
  ExportDirectoryNotifier() : super('') {
    _load();
  }

  /// Whether the current [state] is a user-chosen path (vs. the default).
  bool _isUserChosen = false;

  /// Whether the directory is the user's explicit choice.
  bool get isUserChosen => _isUserChosen;

  /// Persists [path] as the user's explicit choice and updates state.
  Future<void> set(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExportDirectory, path);
    _isUserChosen = true;
    state = path;
  }

  /// Clears the user choice and reverts to the platform default directory.
  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyExportDirectory);
    _isUserChosen = false;
    state = await _safeDefaultDirectory();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyExportDirectory);
    if (saved != null && saved.isNotEmpty) {
      _isUserChosen = true;
      state = saved;
      return;
    }
    _isUserChosen = false;
    state = await _safeDefaultDirectory();
  }

  Future<String> _safeDefaultDirectory() async {
    try {
      return await resolveDefaultExportDirectory();
    } on Object {
      // Keep state empty if the platform default cannot be resolved; the UI
      // will then prompt the user to pick a directory manually.
      return '';
    }
  }
}

/// The directory path used for JSON data exports.
///
/// Resolves to a per-platform default on first run so that automatic exports
/// have a valid target without manual configuration.
final exportDirectoryProvider =
    StateNotifierProvider<ExportDirectoryNotifier, String>(
  (ref) => ExportDirectoryNotifier(),
);
