/// Video panel for the custom H.264 line (0x0310 / CustomByteBlock).
///
/// The custom line carries RAW H.264 Annex-B. media_kit's bundled libmpv ships
/// WITHOUT the raw-H.264 demuxer (only the HEVC raw demuxer, for the official
/// UDP 3334 line), so it fails with "Unknown lavf format h264". fvp's ffmpeg
/// DOES include the raw-H.264 demuxer, so this panel always decodes with fvp,
/// independent of the user's global backend choice.
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

/// Panel body of the custom video screen: real decoder + crosshair + stats.
class CustomVideoPanel extends ConsumerWidget {
  /// Creates a [CustomVideoPanel].
  const CustomVideoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = ref.watch(customVideoControllerProvider);
    final developerMode = ref.watch(developerModeProvider);
    final backend = ref.watch(customVideoBackendProvider);
    final tsWrap = ref.watch(customVideoEffectiveTsWrapProvider);

    // Watch the live stats so the panel rebuilds when the keyframe gate opens.
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

  /// Selects the decoder widget for the chosen [backend].
  ///
  /// fvp is the in-app default (raw codec capable); media_kit is an A/B
  /// alternative (needs [tsWrap] to demux); ffplay spawns an external process
  /// for byte-stream verification. Keyed by [url] + [tsWrap] + [codec] so a
  /// change rebuilds the player with the matching demuxer.
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
// fvp player (raw H.264 / H.265) — direct mdk Player
// ============================================================

/// Decodes the raw custom-video line with a DIRECT mdk [mdk.Player], not the
/// video_player+fvp integration.
///
/// The integration applies fvp's GLOBAL player options to every player, and
/// this app forces `avformat.format=hevc` there for the official UDP 3334 line
/// — which would force the H.264 bridge through the HEVC demuxer and render a
/// white screen. A direct mdk Player skips those globals, so here we set
/// `avformat.format` per player, matching the selected codec and tsWrap.
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

  /// When true the bridge serves MPEG-TS, so the demuxer is forced to `mpegts`
  /// instead of the raw codec format.
  final bool tsWrap;

  /// The video codec (H.264 → `h264`, H.265 → `hevc`).
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

  /// Auto-reconnect watchdog.
  ///
  /// The player is created the instant the keyframe gate opens, which races the
  /// just-started stream: mdk may probe before enough data has landed (only the
  /// single cached keyframe is replayed, and the next MQTT chunk hasn't arrived
  /// yet) or `prepare()` blocks on the live socket, leaving the player stuck
  /// with no texture. Previously this stranded the user on the placeholder /
  /// error state until they tapped 重连 by hand. This watchdog retries the
  /// connection automatically (bounded) so a first attempt that raced the
  /// stream start recovers on its own.
  Timer? _connectWatchdog;

  /// Auto-retries used since the last successful connect (reset on success and
  /// on a manual reconnect).
  int _autoRetries = 0;

  /// Monotonic open-attempt id, so a slow/blocked previous `_open()` that
  /// resumes after a watchdog-triggered reconnect can't clobber the new state.
  int _openGen = 0;

  /// Max automatic reconnect attempts before giving up and waiting for a manual
  /// 重连 (keeps a genuinely dead stream from looping forever).
  static const int _maxAutoRetries = 8;

  /// How long a connect attempt may go without a texture before we retry.
  static const Duration _connectTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// Fires when a connect attempt hasn't produced a texture in time. Retries
  /// the connection (bounded) so a first attempt that raced the stream start
  /// recovers without user intervention.
  void _onConnectTimeout() {
    if (!mounted || _textureId != null) return;
    if (_autoRetries >= _maxAutoRetries) return;
    _autoRetries++;
    _reconnect(auto: true);
  }

  /// Subscribes to the player's event/status streams and prints them, so the
  /// decode failure behind a white screen becomes visible in the console, and
  /// mirrors them into [customVideoDecoderInfoProvider] for the debug panel.
  void _attachDiagnostics(mdk.Player player) {
    final info = ref.read(customVideoDecoderInfoProvider.notifier);
    _diagSubs
      ..add(
        player.onEvent.listen((e) {
          debugPrint(
            '[fvp event] ${e.category} | err=${e.error} | ${e.detail}',
          );
          // mdk reports reader buffering progress via the "reader.buffering"
          // category with the percentage in `error`.
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
    // Arm the watchdog: if this attempt produces no texture within the timeout
    // (raced the stream start / blocked on the live socket), retry automatically.
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(_connectTimeout, _onConnectTimeout);
    final info = ref.read(customVideoDecoderInfoProvider.notifier)
      ..beginSession('fvp', attempt: _attempt);
    final player = mdk.Player();
    _attachDiagnostics(player);
    try {
      // Replicate the official line's PROVEN-WORKING fvp setup. That line plays
      // the SAME kind of live AnnexbTcpServer TCP bridge, but through fvp's
      // video_player integration, which applies the low-latency live-stream
      // config below. A direct mdk.Player (needed here only to force the raw
      // codec demuxer instead of the global hevc force) gets NONE of it by
      // default — and the missing pieces are what stalled us: buffering on a
      // live stream made the reader fill then drain forever (the white screen +
      // `reader.buffering 100 -> 0` loop in the logs), never rendering a frame.
      //
      // setBufferRange(min:0) + fflags=+nobuffer give the real-time, read-
      // forward behaviour that ffplay uses to decode this exact bridge. The
      // bridge now primes every client with the keyframe up front
      // (AnnexbTcpServer), so +nobuffer dropping the very first packet no longer
      // strands the decoder. Decoder priority and avio/avformat flags mirror
      // fvp's own Windows defaults so hardware decode + render behave identically
      // to the official line.
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
      // Dump what mdk actually parsed (codec / resolution / track count) — a
      // white screen with valid video tracks points at decode, not demux.
      final videoTracks = player.mediaInfo.video;
      debugPrint(
        '[fvp mediaInfo] video tracks=${videoTracks?.length} '
        '${videoTracks?.map((v) => v.codec).join(", ")}',
      );
      // Surface the parsed codec/resolution to the debug panel so a black
      // screen can be diagnosed as a decode (not demux) failure at a glance.
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
      // A newer _open() (e.g. watchdog reconnect) superseded this attempt while
      // it was awaiting; discard this one so it can't clobber the new player.
      if (!mounted || gen != _openGen) {
        player.dispose();
        return;
      }
      if (tid >= 0) {
        // Connected and rendering — stop the watchdog and clear the retry budget.
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

  /// Tears down the current player and opens a fresh one.
  ///
  /// [auto] distinguishes a watchdog-driven retry from a user tapping 重连: a
  /// manual reconnect resets the auto-retry budget so the watchdog gets a full
  /// set of attempts again.
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
            child: _ReconnectChip(attempt: _attempt, onReconnect: _reconnect),
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

/// Compact reconnect control overlaid on the video.
class _ReconnectChip extends StatelessWidget {
  const _ReconnectChip({required this.attempt, required this.onReconnect});

  final int attempt;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    return VideoReconnectChip(attempt: attempt, onReconnect: onReconnect);
  }
}

// ============================================================
// Preview placeholder (when not running)
// ============================================================

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({
    this.waitingForKeyframe = false,
    this.codec = CustomVideoCodec.h264,
  });

  /// True once reception has started but the keyframe gate has not opened yet,
  /// so the player is intentionally not connected to the bridge yet.
  final bool waitingForKeyframe;

  /// The active codec (for diagnostic label).
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
// Basic info (always-visible side-panel content)
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
