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
import '../../../../core/widgets/video_side_panel.dart';
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
    final tsWrap = ref.watch(customVideoTsWrapProvider);

    // Watch the live stats so the panel rebuilds when the keyframe gate opens.
    //
    // The decoder must connect only AFTER the gate releases: before that the
    // bridge holds every frame pending (nothing to read), so a low-latency
    // (+nobuffer) player would connect to an empty socket, fail to parse a
    // codec, and never retry — which is why nothing connected automatically.
    // Once the gate opens the bridge primes each new client with the cached
    // keyframe, so creating the player then starts decoding immediately.
    final stats = ref.watch(customVideoStatsProvider).valueOrNull;
    final gateOpen = stats?.gateOpen ?? false;
    final url = stats?.streamUrl;
    final canPlay = isRunning && gateOpen && url != null;

    return Padding(
      padding: context.insetAll(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: canPlay
                ? _buildPlayer(backend, url, developerMode, tsWrap)
                : _PreviewPlaceholder(waitingForKeyframe: isRunning),
          ),
          context.sizedBox(w: 12),
          // The right panel mirrors the UDP line: basic connection info always
          // shown, the full pipeline debug only in developer mode, and 敌方血量
          // bars filling the remaining space.
          Expanded(
            child: VideoSidePanel(
              title: '自定义图传状态',
              developerMode: developerMode,
              basicInfo: const _CustomBasicInfo(),
              debugSection: const CustomVideoDebugContent(),
            ),
          ),
        ],
      ),
    );
  }

  /// Selects the decoder widget for the chosen [backend].
  ///
  /// fvp is the in-app default (raw-H.264 capable); media_kit is an A/B
  /// alternative (needs [tsWrap] to demux); ffplay spawns an external process
  /// for byte-stream verification. Keyed by [url] + [tsWrap] so a change
  /// rebuilds the player with the matching demuxer.
  Widget _buildPlayer(
    VideoDecoderBackend backend,
    String url,
    bool developerMode,
    bool tsWrap,
  ) {
    return switch (backend) {
      VideoDecoderBackend.fvp => _FvpPlayer(
          key: ValueKey('fvp:$url:$tsWrap'),
          url: url,
          developerMode: developerMode,
          tsWrap: tsWrap,
        ),
      VideoDecoderBackend.mediaKit => CustomMediaKitPlayer(
          key: ValueKey('mk:$url:$tsWrap'),
          url: url,
          tsWrap: tsWrap,
        ),
      VideoDecoderBackend.ffplay =>
        CustomFfplayPanel(key: ValueKey(url), streamUrl: url, tsWrap: tsWrap),
    };
  }
}

// ============================================================
// fvp player (raw H.264) — direct mdk Player
// ============================================================

/// Decodes the raw H.264 line with a DIRECT mdk [mdk.Player], not the
/// video_player+fvp integration.
///
/// The integration applies fvp's GLOBAL player options to every player, and
/// this app forces `avformat.format=hevc` there for the official UDP 3334 line
/// — which would force the H.264 bridge through the HEVC demuxer and render a
/// white screen. A direct mdk Player skips those globals, so here we set
/// `avformat.format=h264` per player and decode correctly.
class _FvpPlayer extends ConsumerStatefulWidget {
  const _FvpPlayer({
    required this.url,
    required this.developerMode,
    required this.tsWrap,
    super.key,
  });

  final String url;
  final bool developerMode;

  /// When true the bridge serves MPEG-TS, so the demuxer is forced to `mpegts`
  /// instead of raw `h264`.
  final bool tsWrap;

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

  @override
  void initState() {
    super.initState();
    _open();
  }

  /// Subscribes to the player's event/status streams and prints them, so the
  /// decode failure behind a white screen becomes visible in the console, and
  /// mirrors them into [customVideoDecoderInfoProvider] for the debug panel.
  void _attachDiagnostics(mdk.Player player) {
    final info = ref.read(customVideoDecoderInfoProvider.notifier);
    _diagSubs
      ..add(player.onEvent.listen((e) {
        debugPrint('[fvp event] ${e.category} | err=${e.error} | ${e.detail}');
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
      }))
      ..add(player.onMediaStatus.listen((s) {
        debugPrint('[fvp status] ${s.oldValue} -> ${s.newValue}');
      }))
      ..add(player.onStateChanged.listen((s) {
        debugPrint('[fvp state] ${s.oldValue} -> ${s.newValue}');
        info.setPlaying(playing: s.newValue == mdk.PlaybackState.playing);
      }));
  }

  void _cancelDiagnostics() {
    for (final s in _diagSubs) {
      s.cancel();
    }
    _diagSubs.clear();
  }

  Future<void> _open() async {
    _attempt++;
    if (mounted) setState(() => _error = null);
    final info = ref.read(customVideoDecoderInfoProvider.notifier)
      ..beginSession('fvp', attempt: _attempt);
    final player = mdk.Player();
    _attachDiagnostics(player);
    try {
      // Replicate the official line's PROVEN-WORKING fvp setup. That line plays
      // the SAME kind of live AnnexbTcpServer TCP bridge, but through fvp's
      // video_player integration, which applies the low-latency live-stream
      // config below. A direct mdk.Player (needed here only to force the raw
      // H.264 demuxer instead of the global hevc force) gets NONE of it by
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
        ..setProperty('avformat.format', widget.tsWrap ? 'mpegts' : 'h264')
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
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _textureId = tid >= 0 ? tid : null;
        _error = tid >= 0 ? null : '无法解码视频（已连接但拿不到画面尺寸）';
      });
    } on Object catch (e) {
      player.dispose();
      info.setError('初始化失败: $e');
      if (mounted) setState(() => _error = '初始化失败: $e');
    }
  }

  Future<void> _reconnect() async {
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: const Color(0xFF101418),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reconnect,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重连'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Initializing extends StatelessWidget {
  const _Initializing();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF101418),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              '正在初始化 fvp 解码器…',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(context.sp(6)),
      ),
      child: Padding(
        padding: context.insetSym(h: 8, v: 4),
        child: InkWell(
          onTap: onReconnect,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: Colors.white, size: context.iconSize(14)),
              context.sizedBox(w: 4),
              Text(
                '重连 (第 $attempt 次)',
                style: TextStyle(color: Colors.white, fontSize: context.fontSize(11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Preview placeholder (when not running)
// ============================================================

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({this.waitingForKeyframe = false});

  /// True once reception has started but the keyframe gate has not opened yet,
  /// so the player is intentionally not connected to the bridge yet.
  final bool waitingForKeyframe;

  @override
  Widget build(BuildContext context) {
    if (waitingForKeyframe) {
      return const Card(
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: Color(0xFF101418),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(height: 16),
                Text(
                  '正在接收，等待关键帧…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '收到 SPS/PPS 关键帧后将自动连接解码器',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: const Color(0xFF101418),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: context.iconSize(64), color: Colors.white38),
              context.sizedBox(h: 16),
              Text(
                '未接收自定义图传',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.fontSize(18),
                  fontWeight: FontWeight.w600,
                ),
              ),
              context.sizedBox(h: 8),
              Text(
                '点击右上角播放按钮开始接收 CustomByteBlock',
                style: TextStyle(color: Colors.white54, fontSize: context.fontSize(13)),
              ),
            ],
          ),
        ),
      ),
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
        _StatusRow(isRunning: isRunning),
        context.sizedBox(h: 8),
        if (!isRunning)
          const _InfoRow(label: '状态', value: '未开始接收')
        else ...[
          _InfoRow(label: 'TCP 桥地址', value: stats?.streamUrl ?? '—'),
          _InfoRow(label: '收到 chunk', value: '${stats?.chunksReceived ?? 0}'),
          _InfoRow(label: '收到字节', value: _formatBytes(stats?.bytesReceived ?? 0)),
          _InfoRow(
            label: '关键帧门控',
            value: (stats?.gateOpen ?? false) ? '已打开' : '等待中',
          ),
          _InfoRow(label: '解码器连接数', value: '${stats?.decoderClients ?? 0}'),
          _InfoRow(label: '已转发帧数', value: '${stats?.framesForwarded ?? 0}'),
          _InfoRow(
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final color = isRunning ? Colors.green : Colors.grey;
    return Row(
      children: [
        Container(
          width: context.rmStatusDotSize,
          height: context.rmStatusDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        context.sizedBox(w: 8),
        Text(
          isRunning ? '正在接收 (MQTT CustomByteBlock)' : '已停止',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetSym(v: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
