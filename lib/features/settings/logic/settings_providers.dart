/// Settings-related Riverpod providers with SharedPreferences persistence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ============================================================
// Notifier
// ============================================================

/// Notifier that reads/writes the decoder backend via SharedPreferences.
class VideoDecoderBackendNotifier extends StateNotifier<VideoDecoderBackend> {
  /// Creates the notifier and loads the persisted value.
  VideoDecoderBackendNotifier() : super(VideoDecoderBackend.mediaKit) {
    _load();
  }

  /// Persists [backend] to SharedPreferences and updates state.
  Future<void> set(VideoDecoderBackend backend) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDecoderBackend, backend.index);
    state = backend;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyDecoderBackend);
    if (index != null && index >= 0 && index < VideoDecoderBackend.values.length) {
      state = VideoDecoderBackend.values[index];
    }
  }
}

// ============================================================
// Provider
// ============================================================

/// The user's chosen video decoder backend.
final videoDecoderBackendProvider =
    StateNotifierProvider<VideoDecoderBackendNotifier, VideoDecoderBackend>(
  (ref) => VideoDecoderBackendNotifier(),
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
