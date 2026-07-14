/// 自定义 H.264/H.265 链路（0x0310 / CustomByteBlock）的视频面板。
///
/// 自定义链路可以承载原始 H.264 AnnexB。media_kit 捆绑的 libmpv 往往没有内置
/// 原始 H.264 解复用器（官方 UDP 3334 链路只需要原始 HEVC 解复用器），因此会报
/// “未知 lavf 格式 h264”。fvp 的 ffmpeg 包含原始 H.264 解复用器，因此该面板可以
/// 使用 fvp 作为默认解码路径，并独立于用户的全局后端选择。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/mdk.dart' as mdk;

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/widgets/video_overlay_controls.dart';
import '../../../../core/widgets/video_placeholder_card.dart';
import '../../../../core/widgets/video_side_panel.dart';
import '../../../../core/widgets/video_two_pane_layout.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_video_providers.dart';
import 'crosshair_painter.dart';
import 'custom_ffplay_panel.dart';
import 'custom_mediakit_player.dart';
import 'custom_video_debug_panel.dart';
import 'custom_video_overlay.dart';

/// 自定义图传页面的主体面板：真实解码器、准星和统计信息。
class CustomVideoPanel extends ConsumerWidget {
  /// 创建 [CustomVideoPanel]。
  const CustomVideoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(customVideoControllerProvider);
    final developerMode = ref.watch(developerModeProvider);
    final backend = ref.watch(customVideoBackendProvider);
    final tsWrap = ref.watch(customVideoEffectiveTsWrapProvider);

    // 监听实时统计，使关键帧闸门打开时面板能重建并连接播放器。
    final stats = ref.watch(customVideoStatsProvider).valueOrNull;
    final gateOpen = stats?.gateOpen ?? false;
    final url = stats?.streamUrl;
    final canPlay = isRunning && gateOpen && url != null;
    final codec = stats?.codec ?? CustomVideoCodec.h264;

    return VideoTwoPaneLayout(
      player: canPlay
          ? _buildPlayer(backend, url, developerMode, tsWrap, codec)
          : _PreviewPlaceholder(waitingForKeyframe: isRunning, codec: codec),
      sidePanel: VideoSidePanel(
        title: '自定义图传状态',
        developerMode: developerMode,
        basicInfo: const _CustomBasicInfo(),
        debugSection: const CustomVideoDebugContent(),
      ),
    );
  }

  /// 根据已选择的 [backend] 选择解码器组件。
  ///
  /// fvp 是应用内默认后端，能处理原始编码流；media_kit 是 A/B 备选，通常需要
  /// [tsWrap] 才能正确解复用；ffplay 会启动外部进程用于字节流验证。播放器 key
  /// 由 [url]、[tsWrap] 和 [codec] 共同决定，任一变化都会重建播放器并使用匹配解复用器。
  Widget _buildPlayer(
    VideoDecoderBackend backend,
    String url,
    bool developerMode,
    bool tsWrap,
    CustomVideoCodec codec,
  ) {
    return switch (backend) {
      VideoDecoderBackend.fvp => _FvpPlayer(
        key: ValueKey('fvp:$url:$tsWrap:$codec'),
        url: url,
        developerMode: developerMode,
        tsWrap: tsWrap,
        codec: codec,
      ),
      VideoDecoderBackend.mediaKit => CustomMediaKitPlayer(
        key: ValueKey('mk:$url:$tsWrap:$codec'),
        url: url,
        tsWrap: tsWrap,
        codec: codec,
      ),
      VideoDecoderBackend.ffplay => CustomFfplayPanel(
        key: ValueKey('ff:$url:$tsWrap:$codec'),
        streamUrl: url,
        tsWrap: tsWrap,
        codec: codec,
      ),
    };
  }
}

// ============================================================
// fvp 播放器（原始 H.264 / H.265）——直接使用 mdk 播放器
// ============================================================

/// 使用直接的 [mdk.Player] 解码原始自定义图传链路，而不走 video_player+fvp 集成。
///
/// video_player+fvp 集成会把 fvp 全局播放器选项应用到每个播放器；本应用为了官方
/// UDP 3334 链路曾强制 `avformat.format=hevc`，这会让 H.264 桥接被错误地送入
/// HEVC 解复用器，最终白屏。直接 mdk 播放器可以避开这些全局选项，因此这里按当前
/// 编码格式和 tsWrap 为每个播放器单独设置 `avformat.format`。
class _FvpPlayer extends ConsumerStatefulWidget {
  const _FvpPlayer({
    required this.url,
    required this.developerMode,
    required this.tsWrap,
    required this.codec,
    super.key,
  });

  final String url;
  final bool developerMode;

  /// 为 true 时表示桥接输出 MPEG-TS，此时解复用器强制为 `mpegts`，
  /// 而不是原始编码格式。
  final bool tsWrap;

  /// 视频编码格式（H.264 → `h264`，H.265 → `hevc`）。
  final CustomVideoCodec codec;

  @override
  ConsumerState<_FvpPlayer> createState() => _FvpPlayerState();
}

class _FvpPlayerState extends ConsumerState<_FvpPlayer> {
  mdk.Player? _player;
  int? _textureId;
  String? _error;
  int _attempt = 0;
  final List<StreamSubscription<Object?>> _diagSubs = [];
  Offset? _crosshairCenter;

  /// 自动重连看门狗。
  ///
  /// 播放器会在关键帧闸门打开瞬间创建，此时可能与刚启动的流竞争：mdk 可能在足够数据
  /// 到达前开始探测（只有缓存的单个关键帧被回放，下一块 MQTT 数据尚未到达），也可能在
  /// 实时套接字的 `prepare()` 中阻塞，导致没有 texture。以前用户会停在占位/错误状态，
  /// 直到手动点重连。该看门狗会有界地自动重试，让首次尝试撞上流启动时也能自恢复。
  Timer? _connectWatchdog;

  /// 自上次成功连接以来的自动重试次数；成功或手动重连时重置。
  int _autoRetries = 0;

  /// 单调递增的打开尝试 ID，避免较慢的旧 `_open()` 在看门狗重连后恢复并覆盖新状态。
  int _openGen = 0;

  /// 最大自动重连次数；超过后等待手动重连，避免真正失效的流无限循环。
  static const int _maxAutoRetries = 8;

  /// 单次连接尝试在没有 texture 的情况下可等待多久，超时后重试。
  static const Duration _connectTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// 当连接尝试超时仍未产生 texture 时触发。
  ///
  /// 这里会有界地重试连接，使首次尝试与流启动竞争失败时无需用户介入也能恢复。
  void _onConnectTimeout() {
    if (!mounted || _textureId != null) return;
    if (_autoRetries >= _maxAutoRetries) return;
    _autoRetries++;
    _reconnect(auto: true);
  }

  /// 订阅播放器事件/状态流并打印日志。
  ///
  /// 这样白屏背后的解码失败会显示在控制台，并同步到 [customVideoDecoderInfoProvider]
  /// 供调试面板展示。
  void _attachDiagnostics(mdk.Player player) {
    final info = ref.read(customVideoDecoderInfoProvider.notifier);
    _diagSubs
      ..add(
        player.onEvent.listen((e) {
          debugPrint(
            '[fvp event] ${e.category} | err=${e.error} | ${e.detail}',
          );
          // mdk 通过 "reader.buffering" 分类上报读取缓冲进度，百分比放在 error 字段。
          if (e.category == 'reader.buffering') {
            info.setBuffering(
              buffering: e.error < 100,
              percent: e.error.toDouble(),
            );
          } else {
            info.log(DecoderLogLevel.info, '${e.category}: ${e.detail}');
          }
        }),
      )
      ..add(
        player.onMediaStatus.listen((s) {
          debugPrint('[fvp status] ${s.oldValue} -> ${s.newValue}');
        }),
      )
      ..add(
        player.onStateChanged.listen((s) {
          debugPrint('[fvp state] ${s.oldValue} -> ${s.newValue}');
          info.setPlaying(playing: s.newValue == mdk.PlaybackState.playing);
        }),
      );
  }

  void _cancelDiagnostics() {
    for (final s in _diagSubs) {
      s.cancel();
    }
    _diagSubs.clear();
  }

  Future<void> _open() async {
    _attempt++;
    final gen = ++_openGen;
    if (mounted) setState(() => _error = null);
    // 设置看门狗：如果本次尝试在超时内没有产生 texture（与流启动竞争或阻塞在实时套接字），
    // 就自动重试。
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(_connectTimeout, _onConnectTimeout);
    final info = ref.read(customVideoDecoderInfoProvider.notifier)
      ..beginSession('fvp', attempt: _attempt);
    final player = mdk.Player();
    _attachDiagnostics(player);
    try {
      // 复用官方链路已验证可工作的 fvp 设置。官方链路同样播放实时 AnnexbTcpServer
      // TCP 桥接，但通过 fvp 的 video_player 集成获得了下面这些低延迟直播配置。
      // 这里直接使用 mdk.Player，只是为了按原始编码格式强制解复用器，而不是沿用全局 hevc
      // 强制；直接播放器默认拿不到这些配置。缺失配置会让实时流缓冲反复填满再耗尽
      // （日志中出现 `reader.buffering 100 -> 0` 循环），最终白屏且不渲染帧。
      //
      // setBufferRange(min: 0) + fflags=+nobuffer 提供与 ffplay 相同的实时读取转发行为。
      // AnnexbTcpServer 现在会先用关键帧预热每个客户端，因此 +nobuffer 即使丢掉最初包，
      // 也不会让解码器卡住。解码器优先级和 avio/avformat 参数对齐 fvp 在 Windows 上的
      // 默认行为，使硬解和渲染尽量与官方链路一致。
      player
        ..setProperty(
          'avformat.format',
          widget.tsWrap
              ? 'mpegts'
              : widget.codec == CustomVideoCodec.h265
              ? 'hevc'
              : 'h264',
        )
        ..setProperty('avformat.framerate', '60')
        ..setProperty('avformat.strict', 'experimental')
        ..setProperty('avformat.safe', '0')
        ..setProperty('avio.reconnect', '1')
        ..setProperty('avio.reconnect_delay_max', '7')
        ..setProperty('video.decoder', 'shader_resource=0')
        ..setProperty('avformat.fflags', '+nobuffer')
        ..setProperty('avformat.fpsprobesize', '0')
        ..setProperty('avformat.analyzeduration', '100000')
        ..setProperty('avformat.probesize', '500000')
        ..videoDecoders = ['MFT:d3d=11', 'D3D11', 'DXVA', 'FFmpeg', 'dav1d']
        ..setBufferRange(min: 0)
        ..media = widget.url;
      await player.prepare();
      // 输出 mdk 实际解析到的编码格式、分辨率和轨道数量。白屏但有有效视频轨道时，
      // 问题更可能在解码而不是解复用。
      final videoTracks = player.mediaInfo.video;
      debugPrint(
        '[fvp mediaInfo] video tracks=${videoTracks?.length} '
        '${videoTracks?.map((v) => v.codec).join(", ")}',
      );
      // 将已解析的编码格式/分辨率暴露给调试面板，方便快速判断黑屏是否为解码失败。
      if (videoTracks != null && videoTracks.isNotEmpty) {
        final cp = videoTracks.first.codec;
        info
          ..setResolution(cp.width, cp.height)
          ..setCodec(
            codec: cp.codec,
            pixelFormat: cp.formatName,
            fps: cp.frameRate > 0 ? cp.frameRate : null,
            bitRate: cp.bitRate > 0 ? cp.bitRate : null,
            profile: cp.profile,
          );
      } else {
        info.log(DecoderLogLevel.warn, 'prepare 完成但无视频轨道');
      }
      final tid = await player.updateTexture();
      debugPrint('[fvp] textureId=$tid');
      if (tid < 0) {
        info.setError('无法解码视频（已连接但拿不到画面尺寸）');
      }
      player.state = mdk.PlaybackState.playing;
      // 如果本次等待期间已有更新的 _open()（例如看门狗重连）取代了它，则丢弃旧播放器，
      // 避免旧状态覆盖新播放器。
      if (!mounted || gen != _openGen) {
        player.dispose();
        return;
      }
      if (tid >= 0) {
        // 已连接且开始渲染，停止看门狗并清空重试预算。
        _connectWatchdog?.cancel();
        _connectWatchdog = null;
        _autoRetries = 0;
      }
      setState(() {
        _player = player;
        _textureId = tid >= 0 ? tid : null;
        _error = tid >= 0 ? null : '无法解码视频（已连接但拿不到画面尺寸）';
      });
    } on Object catch (e) {
      player.dispose();
      if (gen != _openGen) return;
      info.setError('初始化失败: $e');
      if (mounted) setState(() => _error = '初始化失败: $e');
    }
  }

  /// 拆除当前播放器并打开一个新播放器。
  ///
  /// [auto] 用于区分看门狗触发的重试和用户手动点击重连。手动重连会重置自动重试预算，
  /// 让看门狗重新获得完整尝试次数。
  Future<void> _reconnect({bool auto = false}) async {
    if (!auto) _autoRetries = 0;
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
    final old = _player;
    _player = null;
    _textureId = null;
    _cancelDiagnostics();
    old?.dispose();
    await _open();
  }

  @override
  void didUpdateWidget(covariant _FvpPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _reconnect();
    }
  }

  @override
  void dispose() {
    _connectWatchdog?.cancel();
    _cancelDiagnostics();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildError(context);
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _textureId != null
                ? GestureDetector(
                    onTapDown: (details) {
                      setState(() {
                        _crosshairCenter = details.localPosition;
                      });
                    },
                    child: CustomPaint(
                      foregroundPainter: CrosshairPainter(
                        aimCenter: _crosshairCenter,
                      ),
                      child: Texture(textureId: _textureId!),
                    ),
                  )
                : const _Initializing(),
          ),
          Positioned(
            top: context.sp(8),
            right: context.sp(8),
            child: VideoReconnectChip(
              attempt: _attempt,
              onReconnect: _reconnect,
            ),
          ),
          if (widget.developerMode)
            Positioned(
              left: context.sp(8),
              bottom: context.sp(8),
              child: const CustomVideoOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return VideoErrorCard(
      message: _error!,
      hint: '已连接但无法拿到画面时，可重连播放器或检查关键帧/编码设置',
      onRetry: _reconnect,
    );
  }
}

class _Initializing extends StatelessWidget {
  const _Initializing();

  @override
  Widget build(BuildContext context) {
    return const VideoPlaceholderCard(
      title: '正在初始化 fvp 解码器…',
      subtitle: '播放器正在连接本地 TCP 图传桥',
      loading: true,
    );
  }
}

// ============================================================
// 预览占位（未运行时）
// ============================================================

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({
    this.waitingForKeyframe = false,
    this.codec = CustomVideoCodec.h264,
  });

  /// 接收已启动但关键帧闸门尚未打开时为 true，此时播放器会刻意暂不连接桥接。
  final bool waitingForKeyframe;

  /// 当前编码格式，用于诊断标签。
  final CustomVideoCodec codec;

  @override
  Widget build(BuildContext context) {
    if (waitingForKeyframe) {
      final paramLabel = codec == CustomVideoCodec.h265
          ? 'VPS/SPS/PPS'
          : 'SPS/PPS';
      return VideoPlaceholderCard(
        title: '正在接收，等待画面…',
        subtitle: '收到 $paramLabel 关键帧后将自动连接解码器',
        loading: true,
      );
    }
    return VideoPlaceholderCard(
      title: '未接收自定义图传 (${codec == CustomVideoCodec.h265 ? "H.265" : "H.264"})',
      subtitle: '点击播放按钮开始接收 0x0310 自定义图传',
    );
  }
}

// ============================================================
// 基础信息（侧边面板始终可见的内容）
// ============================================================

class _CustomBasicInfo extends ConsumerWidget {
  const _CustomBasicInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(customVideoControllerProvider);
    final stats = ref.watch(customVideoStatsProvider).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VideoStatusRow(
          isRunning: isRunning,
          runningLabel: '正在接收 (MQTT CustomByteBlock)',
        ),
        context.sizedBox(h: 8),
        if (!isRunning)
          const VideoInfoRow(label: '状态', value: '未开始接收')
        else ...[
          VideoInfoRow(label: 'TCP 桥地址', value: stats?.streamUrl ?? '—'),
          VideoInfoRow(
            label: '编码格式',
            value: stats?.codec == CustomVideoCodec.h265
                ? 'H.265 / HEVC'
                : 'H.264 / AVC',
          ),
          VideoInfoRow(
            label: '收到 chunk',
            value: '${stats?.chunksReceived ?? 0}',
          ),
          VideoInfoRow(
            label: '收到字节',
            value: _formatBytes(stats?.bytesReceived ?? 0),
          ),
          VideoInfoRow(
            label: '关键帧门控',
            value: (stats?.gateOpen ?? false) ? '已打开' : '等待中',
          ),
          VideoInfoRow(label: '解码器连接数', value: '${stats?.decoderClients ?? 0}'),
          VideoInfoRow(label: '已转发帧数', value: '${stats?.framesForwarded ?? 0}'),
          VideoInfoRow(
            label: '已转发字节',
            value: _formatBytes(stats?.bytesForwarded ?? 0),
          ),
        ],
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }
}
