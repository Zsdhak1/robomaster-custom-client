/// 设置相关 Riverpod Provider，并通过 SharedPreferences 持久化。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../dashboard/logic/dashboard_notification_models.dart';
import '../../data_export/data/default_export_directory.dart';

// ============================================================
// 主题模式 - 浅色 / 深色 / 跟随系统
// ============================================================

const _keyThemeMode = 'theme_mode';

/// 持久化应用 [ThemeMode] 的通知器，默认跟随系统。
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// 创建通知器并加载已持久化的值。
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  /// 按索引持久化 [mode] 并更新状态。
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

/// 用户选择的主题模式（浅色 / 深色 / 跟随系统）。
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

// ============================================================
// 仪表盘通知样式
// ============================================================

const _keyDashboardNotificationStyle = 'dashboard_notification_style';

/// 持久化已选择的仪表盘通知预览样式。
class DashboardNotificationStyleNotifier
    extends StateNotifier<DashboardNotificationStyle> {
  /// 创建通知器并加载已持久化的值。
  DashboardNotificationStyleNotifier()
      : super(DashboardNotificationStyle.topBanner) {
    _load();
  }

  /// 持久化 [style] 并更新状态。
  Future<void> set(DashboardNotificationStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDashboardNotificationStyle, style.index);
    state = style;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyDashboardNotificationStyle);
    if (index != null &&
        index >= 0 &&
        index < DashboardNotificationStyle.values.length) {
      state = DashboardNotificationStyle.values[index];
    }
  }
}

/// 用户当前选择的仪表盘事件通知样式。
final dashboardNotificationStyleProvider = StateNotifierProvider<
    DashboardNotificationStyleNotifier, DashboardNotificationStyle>(
  (ref) => DashboardNotificationStyleNotifier(),
);

// ============================================================
// 自定义图传编码格式 - H.264 或 H.265 (HEVC)
// ============================================================

/// 自定义 0x0310 图传链路使用的视频编码格式。
///
/// 机器人可能通过 `CustomByteBlock` 输出 H.264 AnnexB 或 HEVC AnnexB。
/// 该设置决定关键帧闸门、解复用器和 NAL 扫描器应按哪种位布局解析。
enum CustomVideoCodec {
  /// H.264 / AVC — 5‑位 nal_单元_type，参数集 SPS=7 / PPS=8。
  h264('H.264', 'sps=7, pps=8'),

  /// H.265 / HEVC — 6‑位 nal_单元_type，参数集 VPS=32 / SPS=33 / PPS=34。
  h265('H.265 / HEVC', 'vps=32, sps=33, pps=34');

  const CustomVideoCodec(this.label, this.nalDescription);

  /// 简短可读标签。
  final String label;

  /// 当前编码格式中哪些 NAL 类型构成“参数集”。
  final String nalDescription;
}

const _keyCustomVideoCodec = 'custom_video_codec';

/// 持久化自定义图传编码格式的通知器，默认 H.264。
class CustomVideoCodecNotifier extends StateNotifier<CustomVideoCodec> {
  /// 创建通知器并加载已持久化的值。
  CustomVideoCodecNotifier() : super(CustomVideoCodec.h264) {
    _load();
  }

  /// 持久化 [codec] 并更新状态。
  Future<void> set(CustomVideoCodec codec) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomVideoCodec, codec.index);
    state = codec;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final i = prefs.getInt(_keyCustomVideoCodec);
    if (i != null && i >= 0 && i < CustomVideoCodec.values.length) {
      state = CustomVideoCodec.values[i];
    }
  }
}

/// 自定义 0x0310 链路应使用的视频编码格式。
final customVideoCodecProvider =
    StateNotifierProvider<CustomVideoCodecNotifier, CustomVideoCodec>(
  (ref) => CustomVideoCodecNotifier(),
);

// ============================================================
// 视频解码器后端
// ============================================================

/// 用户可选择的视频解码后端。
enum VideoDecoderBackend {
  /// media_kit：基于 libmpv，跨平台更稳健。
  mediaKit,

  /// fvp：基于 libmdk，延迟更低。
  fvp,

  /// ffplay 子进程（Windows），在独立窗口渲染。
  ffplay,
}

/// [VideoDecoderBackend] 的可读标签和说明。
extension VideoDecoderBackendLabel on VideoDecoderBackend {
  /// 简短中文标签。
  String get label => switch (this) {
        VideoDecoderBackend.mediaKit => 'media_kit',
        VideoDecoderBackend.fvp => 'fvp',
        VideoDecoderBackend.ffplay => 'ffplay (验证)',
      };

  /// 单行中文描述。
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
// SharedPreferences 存储键
// ============================================================

const _keyDecoderBackend = 'video_decoder_backend';
const _keyCustomVideoBackend = 'custom_video_decoder_backend';

// ============================================================
// 通知器
// ============================================================

/// 通过 SharedPreferences 读取和写入解码后端的通知器。
///
/// 通过 [_prefsKey] 和 [_fallback] 参数化，使官方 UDP 链路和自定义 0x0310 链路
/// 可以复用同一实现，同时拥有各自独立持久化的后端选择。
class VideoDecoderBackendNotifier extends StateNotifier<VideoDecoderBackend> {
  /// 创建通知器并加载已持久化的值。
  VideoDecoderBackendNotifier({
    required this._prefsKey,
    VideoDecoderBackend fallback = VideoDecoderBackend.mediaKit,
  })  : _fallback = fallback,
        super(fallback) {
    _load();
  }

  final String _prefsKey;
  final VideoDecoderBackend _fallback;

  /// 将 [backend] 持久化到 SharedPreferences 并更新状态。
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
// Provider 定义
// ============================================================

/// 用户为官方 UDP 3334 链路选择的视频解码后端。
final videoDecoderBackendProvider =
    StateNotifierProvider<VideoDecoderBackendNotifier, VideoDecoderBackend>(
  (ref) => VideoDecoderBackendNotifier(prefsKey: _keyDecoderBackend),
);

/// 用户为自定义 0x0310 H.264/H.265 链路选择的解码后端。
///
/// 独立于 [videoDecoderBackendProvider]，便于对原始自定义视频流做 A/B 测试
/// （fvp vs media_kit），或用外部 ffplay 验证，而不影响官方 HEVC 链路。
/// 默认使用 fvp，因为它在桌面端内置原始 H.264 解复用能力。
final customVideoBackendProvider =
    StateNotifierProvider<VideoDecoderBackendNotifier, VideoDecoderBackend>(
  (ref) => VideoDecoderBackendNotifier(
    prefsKey: _keyCustomVideoBackend,
    fallback: VideoDecoderBackend.fvp,
  ),
);

// ============================================================
// 硬件解码器（libmpv `hwdec`）- 作用于 media_kit 后端
// ============================================================

/// libmpv `hwdec` 模式。
///
/// [value] 会原样传给 mpv 的 `hwdec` 属性；不支持的选择会让 mpv 回退到软件解码。
///
/// 覆盖本应用目标平台（Android / Windows / Linux）以及通用跨平台选项。
enum HwdecMode {
  /// 启用任意可用解码器。
  auto('auto', 'auto', '启用任意可用解码器'),

  /// 启用白名单内的最佳解码器（推荐默认值）。
  autoSafe('auto-safe', 'auto-safe', '启用最佳解码器（推荐）'),

  /// 启用带读回复制到系统内存的最佳解码器。
  autoCopy('auto-copy', 'auto-copy', '启用带拷贝功能的最佳解码器'),

  /// 强制使用软件解码。
  none('no', 'no', '关闭硬件解码，强制软件解码'),

  /// DirectX 11 视频加速（Windows 8+）。
  d3d11va('d3d11va', 'd3d11va', 'DirectX11 (Windows8 及以上)'),

  /// DirectX 11 视频加速，非零拷贝。
  d3d11vaCopy('d3d11va-copy', 'd3d11va-copy', 'DirectX11 (Windows8 及以上) (非直通)'),

  /// DirectX 9 视频加速（Windows 7+）。
  dxva2('dxva2', 'dxva2', 'DXVA2 (Windows7 及以上)'),

  /// DirectX 9 视频加速，非零拷贝。
  dxva2Copy('dxva2-copy', 'dxva2-copy', 'DXVA2 (Windows7 及以上) (非直通)'),

  /// Android MediaCodec 硬件解码器。
  mediacodec('mediacodec', 'mediacodec', 'MediaCodec (Android)'),

  /// Android MediaCodec，非零拷贝。
  mediacodecCopy('mediacodec-copy', 'mediacodec-copy', 'MediaCodec (Android) (非直通)'),

  /// VA-API 硬件解码器（Linux）。
  vaapi('vaapi', 'vaapi', 'VAAPI (Linux)'),

  /// VA-API，非零拷贝。
  vaapiCopy('vaapi-copy', 'vaapi-copy', 'VAAPI (Linux) (非直通)'),

  /// NVIDIA NVDEC 硬件解码器。
  nvdec('nvdec', 'nvdec', 'NVDEC (NVIDIA 独占)'),

  /// NVIDIA NVDEC，非零拷贝。
  nvdecCopy('nvdec-copy', 'nvdec-copy', 'NVDEC (NVIDIA 独占) (非直通)'),

  /// DRM 硬件解码器（Linux）。
  drm('drm', 'drm', 'DRM (Linux)'),

  /// DRM，非零拷贝。
  drmCopy('drm-copy', 'drm-copy', 'DRM (Linux) (非直通)'),

  /// VideoToolbox 硬件解码器（macOS / iOS）。
  videotoolbox('videotoolbox', 'videotoolbox', 'VideoToolbox (macOS / iOS)'),

  /// VideoToolbox，非零拷贝。
  videotoolboxCopy(
      'videotoolbox-copy', 'videotoolbox-copy', 'VideoToolbox (macOS / iOS) (非直通)'),

  /// Vulkan 硬件解码器（实验性，跨平台）。
  vulkan('vulkan', 'vulkan', 'Vulkan (全平台) (实验性)'),

  /// Vulkan，非零拷贝。
  vulkanCopy('vulkan-copy', 'vulkan-copy', 'Vulkan (全平台) (实验性) (非直通)');

  const HwdecMode(this.value, this.label, this.description);

  /// 传给 mpv `hwdec` 属性的精确字符串。
  final String value;

  /// 选择器中显示的短标签。
  final String label;

  /// 单行中文描述。
  final String description;

  /// 将已持久化的 [value] 解析回枚举，无法识别时默认 [autoSafe]。
  static HwdecMode fromValue(String? v) {
    for (final m in HwdecMode.values) {
      if (m.value == v) return m;
    }
    return HwdecMode.autoSafe;
  }
}

const _keyHwdec = 'video_hwdec_mode';

/// 按 mpv 字符串值持久化已选择 [HwdecMode] 的通知器。
class HwdecModeNotifier extends StateNotifier<HwdecMode> {
  /// 创建通知器并加载已持久化的值。
  HwdecModeNotifier() : super(HwdecMode.autoSafe) {
    _load();
  }

  /// 持久化 [mode] 并更新状态。
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

/// 用户选择的 libmpv 硬件解码模式。
final hwdecModeProvider =
    StateNotifierProvider<HwdecModeNotifier, HwdecMode>(
  (ref) => HwdecModeNotifier(),
);

// ============================================================
// 开发者模式 - 控制所有调试组件的可见性
// ============================================================

const _keyDeveloperMode = 'developer_mode';

/// 持久化开发者模式开关的通知器，默认关闭。
class DeveloperModeNotifier extends StateNotifier<bool> {
  /// 创建通知器并加载已持久化的值。
  DeveloperModeNotifier() : super(false) {
    _load();
  }

  /// 持久化 [enabled] 并更新状态。
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

/// 开发者模式是否开启；关闭时隐藏所有调试组件。
final developerModeProvider =
    StateNotifierProvider<DeveloperModeNotifier, bool>(
  (ref) => DeveloperModeNotifier(),
);

// ============================================================
// 自定义图传 MPEG-TS 封装
// ============================================================

const _keyCustomVideoTsWrap = 'custom_video_ts_wrap';

/// 持久化自定义 0x0310 链路是否封装为 MPEG-TS 的通知器。
class CustomVideoTsWrapNotifier extends StateNotifier<bool> {
  /// 创建通知器并加载已持久化的值，默认关闭。
  CustomVideoTsWrapNotifier() : super(false) {
    _load();
  }

  /// 持久化 [enabled] 并更新状态。
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

/// 自定义 H.264/H.265 链路在对外服务前是否封装为 MPEG-TS。
///
/// 关闭时桥接输出原始 AnnexB，fvp 可直接解码；开启时桥接输出 MPEG-TS，
/// media_kit 的 libmpv 能正确解复用，从而绕过缺少原始 H.264 解复用器的问题。
/// 两个应用内播放器会随该值切换强制解复用格式。
final customVideoTsWrapProvider =
    StateNotifierProvider<CustomVideoTsWrapNotifier, bool>(
  (ref) => CustomVideoTsWrapNotifier(),
);

/// 实际应用到流水线的 TS wrap 值，也是唯一事实来源。
///
/// media_kit 捆绑的 libmpv 没有原始 H.264 解复用器，因此只有桥接输出 MPEG-TS 时
/// 才能解码该链路。选择 media_kit 后端会强制开启 TS，不受用户手动开关影响；
/// 其他后端（fvp、ffplay）可以解码原始 AnnexB，因此遵循用户设置。
///
/// 流控制器（决定桥接输出字节）和面板（决定播放器强制解复用器）都读取该值，
/// 确保服务格式与播放器解复用器不会不一致；这种不一致正是 media_kit 卡在 0:00 的原因。
final customVideoEffectiveTsWrapProvider = Provider<bool>((ref) {
  final userTsWrap = ref.watch(customVideoTsWrapProvider);
  final backend = ref.watch(customVideoBackendProvider);
  return userTsWrap || backend == VideoDecoderBackend.mediaKit;
});

// ============================================================
// 自定义图传包切片 - 将每个 CustomByteBlock.data 转换为解码器输入的 AnnexB 字节流
// ============================================================

/// 从每个 `CustomByteBlock.data` 中提取视频字节的策略。
///
/// 抓包显示机器人会在每个包的视频载荷前放入一个带内 protobuf 风格长度前缀：
/// `0x0A` + varint 长度 + 载荷 + 可选填充。原样转发会把这些前缀周期性注入流中，
/// 破坏它落入的 NAL；关键帧跨多个包时几乎必然被破坏。以下模式用于实时剥离前缀或
/// A/B 验证行为。
enum CustomVideoSliceMode {
  /// 原样转发 `data`。作为 A/B 基线使用，已知会把长度前缀注入流中。
  verbatim('原样转发 (verbatim)', '直接转发整个 data，含包头前缀，仅作对比基线'),

  /// 自动检测 `0x0A <varint>` 前缀，只发出声明的载荷字节，并丢弃前缀和尾部填充。
  stripPrefix('自动剥离包头 (推荐)', '识别 0x0A+varint 长度前缀，仅取声明的负载字节'),

  /// 手动跳过固定包头，并截取固定长度载荷（由滑块设定）。
  fixed('固定切片 (手动)', '跳过固定包头字节，取固定长度负载（用下方滑块设定）');

  const CustomVideoSliceMode(this.label, this.description);

  /// 选择器中显示的短中文标签。
  final String label;

  /// 单行中文描述。
  final String description;

  /// 将已持久化索引解析为枚举，无法识别时默认 [stripPrefix]。
  static CustomVideoSliceMode fromIndex(int? i) {
    if (i != null && i >= 0 && i < CustomVideoSliceMode.values.length) {
      return CustomVideoSliceMode.values[i];
    }
    return CustomVideoSliceMode.stripPrefix;
  }
}

const _keyCustomVideoSliceMode = 'custom_video_slice_mode';

/// 持久化 [CustomVideoSliceMode] 的通知器，默认 [stripPrefix]。
class CustomVideoSliceModeNotifier extends StateNotifier<CustomVideoSliceMode> {
  /// 创建通知器并加载已持久化的值。
  CustomVideoSliceModeNotifier() : super(CustomVideoSliceMode.stripPrefix) {
    _load();
  }

  /// 持久化 [mode] 并更新状态。
  Future<void> set(CustomVideoSliceMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomVideoSliceMode, mode.index);
    state = mode;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = CustomVideoSliceMode.fromIndex(
      prefs.getInt(_keyCustomVideoSliceMode),
    );
  }
}

/// 自定义 0x0310 链路当前使用的包切片策略，实时生效。
final customVideoSliceModeProvider =
    StateNotifierProvider<CustomVideoSliceModeNotifier, CustomVideoSliceMode>(
  (ref) => CustomVideoSliceModeNotifier(),
);

// ============================================================
// 自定义图传序列头 - 前置 uint64 LE 包序列号
// ============================================================

/// 机器人为丢包检测添加到每个 `CustomByteBlock.data` 前的 uint64 小端序序列号长度。
const int customVideoSeqHeaderBytes = 8;

const _keyCustomVideoSeqHeader = 'custom_video_seq_header';

/// 持久化每个包是否以 8 字节 uint64 LE 序列号开头的通知器，默认开启。
///
/// 开启时，数据源读取序列号，根据序列间隔计算丢包率，并在切片视频载荷前剥离这
/// 8 字节。如果机器人固件退回到不带序列头的流，则应关闭。
class CustomVideoSeqHeaderNotifier extends StateNotifier<bool> {
  /// 创建通知器并加载已持久化的值，默认开启。
  CustomVideoSeqHeaderNotifier() : super(true) {
    _load();
  }

  /// 持久化 [enabled] 并更新状态。
  Future<void> set({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCustomVideoSeqHeader, enabled);
    state = enabled;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_keyCustomVideoSeqHeader) ?? true;
  }
}

/// 每个包是否携带前置 uint64 LE 序列号，实时生效。
final customVideoSeqHeaderProvider =
    StateNotifierProvider<CustomVideoSeqHeaderNotifier, bool>(
  (ref) => CustomVideoSeqHeaderNotifier(),
);

// ============================================================
// 自定义图传载荷字节数 - 每包视频数据长度
// ============================================================

/// 每个 `CustomByteBlock` 中位于视频载荷前的固定前缀字节数。
///
/// 机器人将每个 0x0310 包组织为 `[3 字节头部][N 字节视频][padding]`。
/// 头部长度固定，只有视频字节数 N 可由用户调整（见 [customVideoPayloadBytesProvider]）。
const int customVideoHeaderBytes = 3;

/// 每个 `CustomByteBlock` 默认携带的视频载荷字节数。
const int customVideoDefaultPayloadBytes = 150;

/// UI 可选择的最小/最大载荷字节数。
const int customVideoMinPayloadBytes = 1;
const int customVideoMaxPayloadBytes = 297;

const _keyCustomVideoPayloadBytes = 'custom_video_payload_bytes';

/// 持久化每个包要切出的有效视频字节数。
///
/// 每个 `CustomByteBlock.data` 的结构为 `[头部][载荷][padding]`；数据源切出
/// `data[0 .. 头部 + 载荷]` 并拼接为 AnnexB 流。该值在下一个包立即生效，因为数据源
/// 每个块都会读取实时 Provider 值，不需要重启。
class CustomVideoPayloadBytesNotifier extends StateNotifier<int> {
  /// 创建通知器并加载已持久化的值，默认 150。
  CustomVideoPayloadBytesNotifier() : super(customVideoDefaultPayloadBytes) {
    _load();
  }

  /// 将 [bytes] 钳制到有效范围后持久化并更新状态。
  Future<void> set(int bytes) async {
    final clamped =
        bytes.clamp(customVideoMinPayloadBytes, customVideoMaxPayloadBytes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomVideoPayloadBytes, clamped);
    state = clamped;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_keyCustomVideoPayloadBytes);
    if (saved != null) {
      state =
          saved.clamp(customVideoMinPayloadBytes, customVideoMaxPayloadBytes);
    }
  }
}

/// 每个 `CustomByteBlock` 中切出的有效视频数据字节数。
///
/// 实时生效：[CustomByteBlockSource] 每包读取该值，因此设置页调试滑块可以在不重启流的
/// 情况下重新调节切片长度。
final customVideoPayloadBytesProvider =
    StateNotifierProvider<CustomVideoPayloadBytesNotifier, int>(
  (ref) => CustomVideoPayloadBytesNotifier(),
);

// ============================================================
// 导出目录 - JSON 导出文件保存位置
// ============================================================

const _keyExportDirectory = 'export_directory';

/// 持久化 JSON 导出目录路径的通知器。
///
/// 首次运行且用户未选择路径时，会回退到 [resolveDefaultExportDirectory] 解析出的
/// 平台默认目录，使自动记录和保存无需手动配置即可工作。用户选择会被持久化并优先使用；
/// [resetToDefault] 会恢复平台默认值。
class ExportDirectoryNotifier extends StateNotifier<String> {
  /// 创建通知器并加载已持久化路径或默认路径。
  ExportDirectoryNotifier() : super('') {
    _load();
  }

  /// 当前 [state] 是否为用户显式选择的路径，而非默认路径。
  bool _isUserChosen = false;

  /// 目录是否由用户显式选择。
  bool get isUserChosen => _isUserChosen;

  /// 将 [path] 作为用户显式选择持久化并更新状态。
  Future<void> set(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExportDirectory, path);
    _isUserChosen = true;
    state = path;
  }

  /// 清空用户选择并恢复到平台默认目录。
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
      // 如果平台默认目录无法解析，则保留空状态；UI 会提示用户手动选择目录。
      return '';
    }
  }
}

/// JSON 数据导出使用的目录路径。
///
/// 首次运行时解析为平台默认值，确保自动导出无需手动配置也有有效目标。
final exportDirectoryProvider =
    StateNotifierProvider<ExportDirectoryNotifier, String>(
  (ref) => ExportDirectoryNotifier(),
);

// ============================================================
// 仪表盘血量趋势图显示开关
// ============================================================

const _keyShowHealthTrend = 'show_health_trend';

/// 持久化仪表盘是否显示血量趋势图的通知器。
class ShowHealthTrendNotifier extends StateNotifier<bool> {
  /// 创建通知器并加载已持久化的值，默认开启。
  ShowHealthTrendNotifier() : super(true) {
    _load();
  }

  /// 持久化 [enabled] 并更新状态。
  Future<void> set({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowHealthTrend, enabled);
    state = enabled;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_keyShowHealthTrend) ?? true;
  }
}

/// 仪表盘血量趋势图是否可见。
///
/// 禁用后，底部区域会改为显示操作面板和连接质量面板。
final showHealthTrendProvider =
    StateNotifierProvider<ShowHealthTrendNotifier, bool>(
  (ref) => ShowHealthTrendNotifier(),
);
