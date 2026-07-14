/// 带真实解码器渲染的视频流监控面板。
///
/// 支持两个后端：
///  • media_kit（libmpv）— 通过 [videoDecoderBackendProvider] 选择
///  • fvp（通过 video_player 使用 libmdk）— 通过同一 Provider 选择
///
/// 两者都消费本地回环 TCP 桥接提供的 AnnexB 流。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/video/video_frame.dart';
import '../../../../core/widgets/video_overlay_controls.dart';
import '../../../../core/widgets/video_placeholder_card.dart';
import '../../../../core/widgets/video_side_panel.dart';
import '../../../../core/widgets/video_two_pane_layout.dart';
import '../../../settings/logic/settings_providers.dart';
import '../../logic/stream_providers.dart';
import 'video_debug_panel.dart';

/// 视频页面的面板主体：真实播放器和流统计。
class VideoPanel extends ConsumerWidget {
  /// 创建 [VideoPanel]。
  const VideoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isListening = ref.watch(videoStreamControllerProvider);
    final backend = ref.watch(videoDecoderBackendProvider);
    final hwdec = ref.watch(hwdecModeProvider);
    final developerMode = ref.watch(developerModeProvider);
    final latestFrame = ref.watch(videoFrameProvider).valueOrNull;
    final url = isListening
        ? ref.read(videoStreamServiceProvider).streamUrl
        : null;

    return VideoTwoPaneLayout(
      player: isListening && url != null
          ? _buildPlayer(url, backend, hwdec, developerMode: developerMode)
          : _PreviewPlaceholder(isListening: isListening),
      sidePanel: VideoSidePanel(
        title: '视频流状态',
        developerMode: developerMode,
        basicInfo: _BasicInfo(
          isListening: isListening,
          frame: latestFrame,
          url: url,
        ),
        debugSection: const VideoDebugContent(),
      ),
    );
  }

  Widget _buildPlayer(
    String url,
    VideoDecoderBackend backend,
    HwdecMode hwdec, {
    required bool developerMode,
  }) {
    return switch (backend) {
      VideoDecoderBackend.mediaKit => _MediaKitPlayer(
        url: url,
        hwdec: hwdec.value,
        developerMode: developerMode,
      ),
      VideoDecoderBackend.fvp => _FvpPlayer(url: url),
      VideoDecoderBackend.ffplay => const _FfplayPanel(),
    };
  }
}

// ============================================================
// media_kit 播放器
// ============================================================

class _MediaKitPlayer extends StatefulWidget {
  const _MediaKitPlayer({
    required this.url,
    required this.hwdec,
    required this.developerMode,
  });

  final String url;

  /// libmpv `hwdec` 属性值，例如 `auto-safe`、`d3d11va`、`no`。
  final String hwdec;

  /// 为 false 时，覆盖层只显示一个重连按钮。
  final bool developerMode;

  @override
  State<_MediaKitPlayer> createState() => _MediaKitPlayerState();
}

class _MediaKitPlayerState extends State<_MediaKitPlayer> {
  late final Player _player;
  late final VideoController _controller;

  StreamSubscription<String>? _errorSub;
  StreamSubscription<PlayerLog>? _logSub;
  StreamSubscription<bool>? _playingSub;

  /// libmpv 最近报告的错误，会作为覆盖层显示。
  String? _lastError;

  /// libmpv 是否已经开始解码或播放帧。
  bool _playing = false;

  /// 本会话中已经打开或重新打开流的次数。
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    // warn 级日志会暴露 libmpv 的连接和解复用诊断，便于看到解码器为何无法连接 TCP 桥接。
    // 默认 error 级别会隐藏“连接失败/打开失败”的链路细节。
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _controller = VideoController(_player);

    // 暴露 libmpv 的真实失败原因，避免被静默吞掉。
    _errorSub = _player.stream.error.listen((msg) {
      debugPrint('media_kit error: $msg');
      if (mounted) setState(() => _lastError = msg);
    });
    _logSub = _player.stream.log.listen((log) {
      debugPrint('media_kit log [${log.level}] ${log.prefix}: ${log.text}');
    });
    _playingSub = _player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    });

    _configureAndOpen();
  }

  /// 配置 libmpv 并打开流。
///
  /// 关键修复是 `load-unsafe-playlists=yes`：media_kit 通过临时播放列表和 `loadlist`
  /// 加载 URL，而 libmpv 默认拒绝播放列表中的 tcp:// 条目，这会导致解码器从未连接。
  /// 其余参数对齐 VLC 已验证的 `:demux=hevc :network-caching=1000` 设置。
  Future<void> _configureAndOpen() async {
    _attempt++;
    if (mounted) setState(() => _lastError = null);
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        // “解码器连接:0”的根因：media_kit.open() 不直接 loadfile URL，
        // 而是把 URL 写入临时播放列表并执行 `loadlist`。libmpv 会拒绝播放列表里的 tcp:// 条目，
        // 因而从未打开流，桥接端看到的客户端数始终为 0。
        // 该选项必须在 open() 之前设置，因为 open() 内部会运行 loadlist。
        await platform.setProperty('load-unsafe-playlists', 'yes');
        // 等价于 VLC :demux=hevc，强制原始 HEVC 解复用器并跳过探测。
        await platform.setProperty('demuxer-lavf-format', 'hevc');
        // 原始流没有时间戳，假定 60fps 以便 PTS 推进。
        await platform.setProperty('demuxer-lavf-o', 'framerate=60');
        // 等价于 VLC :network-caching=1000，提供约 1 秒缓冲，让解复用器有足够字节锁定。
        // 旧的 `cache=no` 是 VLC 能显示而 media_kit 无内容的根因。
        await platform.setProperty('cache', 'yes');
        await platform.setProperty('demuxer-readahead-secs', '0.3');
        await platform.setProperty('cache-secs', '0.3');
        // 用户选择的硬件解码器；如果平台不支持，mpv 会自动回退到软件解码。
        await platform.setProperty('hwdec', widget.hwdec);
      } on Object catch (e) {
        debugPrint('media_kit property warning: $e');
      }
    }
    try {
      await _player.open(Media(widget.url));
    } on Object catch (e) {
      debugPrint('media_kit open error: $e');
      if (mounted) setState(() => _lastError = '打开失败: $e');
    }
  }

  /// 关闭当前流并从头重新打开。
///
  /// 当解码器连接失败或流停滞时使用，强制 libmpv 丢弃内部状态并重连 TCP 桥接，
  /// 从而重新触发关键帧闸门。
  Future<void> _reconnect() async {
    try {
      await _player.stop();
    } on Object catch (e) {
      debugPrint('media_kit stop error: $e');
    }
    await _configureAndOpen();
  }

  @override
  void didUpdateWidget(covariant _MediaKitPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URL 或 hwdec 变化时重新打开；hwdec 只在加载时生效。
    if (oldWidget.url != widget.url || oldWidget.hwdec != widget.hwdec) {
      _configureAndOpen();
    }
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    _logSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: Video(controller: _controller)),
          Positioned(
            top: 8,
            right: 8,
            child: _MediaKitOverlay(
              playing: _playing,
              error: _lastError,
              attempt: _attempt,
              developerMode: widget.developerMode,
              onReconnect: _reconnect,
            ),
          ),
        ],
      ),
    );
  }
}

/// 叠加在 media_kit 视频上的状态标签和重连控件。
///
/// [developerMode] 关闭时只显示紧凑重连按钮，普通用户也能手动重连；
/// 浅色状态、尝试计数和错误详情仅面向开发者。
class _MediaKitOverlay extends StatelessWidget {
  const _MediaKitOverlay({
    required this.playing,
    required this.error,
    required this.attempt,
    required this.developerMode,
    required this.onReconnect,
  });

  final bool playing;
  final String? error;
  final int attempt;
  final bool developerMode;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    if (!developerMode) {
      // 普通用户只保留重连入口。
      return _pill(context, child: _reconnectButton(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStatusChip(context),
        if (error != null) _buildErrorBox(context),
      ],
    );
  }

  Widget _reconnectButton(BuildContext context) {
    return InkWell(
      onTap: onReconnect,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.refresh, color: Colors.white, size: 14),
          const SizedBox(width: 2),
          Text(
            '重连',
            style: context.textTheme.labelSmall!.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final hasError = error != null;
    final color = hasError
        ? Colors.red
        : playing
        ? Colors.green
        : Colors.orange;
    final label = hasError
        ? '解码错误'
        : playing
        ? '播放中'
        : '连接中…';
    return _pill(
      context,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label (第 $attempt 次)',
            style: context.textTheme.labelSmall!.copyWith(color: Colors.white),
          ),
          const SizedBox(width: 8),
          _reconnectButton(context),
        ],
      ),
    );
  }

  Widget _buildErrorBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: _pill(
          context,
          child: Text(
            error!,
            style: context.textTheme.labelSmall!.copyWith(color: Colors.orange),
          ),
        ),
      ),
    );
  }

  /// 状态标签和错误框共用的半透明圆角容器。
  Widget _pill(BuildContext context, {required Widget child}) {
    return VideoOverlayPill(child: child);
  }
}

// ============================================================
// fvp 播放器 (通过 video_player)
// ============================================================

class _FvpPlayer extends StatefulWidget {
  const _FvpPlayer({required this.url});

  final String url;

  @override
  State<_FvpPlayer> createState() => _FvpPlayerState();
}

class _FvpPlayerState extends State<_FvpPlayer> {
  late VideoPlayerController _controller;
  String? _error;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {});
              _controller.play();
            }
          })
          .catchError((Object e) {
            if (mounted) {
              setState(() => _error = '初始化失败: $e');
            }
          });
  }

  @override
  void didUpdateWidget(covariant _FvpPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.dispose();
      _error = null;
      _initController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _resetSystemUi();
    super.dispose();
  }

  Future<void> _toggleFullscreen() async {
    final target = !_isFullscreen;
    setState(() => _isFullscreen = target);
    if (target) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _resetSystemUi();
    }
  }

  Future<void> _resetSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _buildError();
    final initialized = _controller.value.isInitialized;
    final aspectRatio = _controller.value.aspectRatio > 0
        ? _controller.value.aspectRatio
        : 16 / 9;

    Widget player = Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: initialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                AspectRatio(
                  aspectRatio: aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                _FvpControls(
                  controller: _controller,
                  isFullscreen: _isFullscreen,
                  onToggleFullscreen: _toggleFullscreen,
                ),
              ],
            )
          : const VideoPlaceholderCard(
              title: '正在初始化 fvp 播放器…',
              subtitle: '播放器正在连接本地 TCP 图传桥',
              loading: true,
            ),
    );

    if (_isFullscreen) {
      // 全屏时隐藏周围行和内边距，让视频填满页面。
      // 调用方仍持有状态，因此原地重建；底层 Scaffold 的 appBar/FAB 会随系统 UI 模式自动隐藏。
      player = Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: player),
      );
    }

    return player;
  }

  Widget _buildError() {
    return VideoErrorCard(
      message: _error!,
      hint: 'fvp 可能不支持 tcp:// 协议，请尝试切换到 media_kit',
    );
  }
}

/// fvp 后端使用的覆盖层控件：播放/暂停、进度拖动、时间、静音和全屏。
class _FvpControls extends StatefulWidget {
  const _FvpControls({
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final VideoPlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  State<_FvpControls> createState() => _FvpControlsState();
}

class _FvpControlsState extends State<_FvpControls> {
  /// 用户当前是否正在拖动进度条。
  bool _dragging = false;

  /// 拖动期间使用的值，会覆盖控制器当前位置。
  Duration _dragPosition = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final showBigPlay =
            value.isInitialized && !value.isPlaying && !value.isBuffering;
        return Stack(
          fit: StackFit.expand,
          children: [
            // 点击视频切换播放/暂停。
            GestureDetector(
              onTap: () {
                value.isPlaying
                    ? widget.controller.pause()
                    : widget.controller.play();
              },
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
            if (showBigPlay)
              Center(
                child: _ControlsButton(
                  icon: Icons.play_arrow,
                  size: 64,
                  onPressed: widget.controller.play,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(value),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(VideoPlayerValue value) {
    final position = _dragging ? _dragPosition : value.position;
    final duration = value.duration;
    final buffered = value.buffered.isNotEmpty
        ? value.buffered.last.end
        : Duration.zero;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Theme.of(context).colorScheme.scrim.withValues(alpha: 0.7),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressSlider(value, position, duration, buffered),
            const SizedBox(height: 4),
            Row(
              children: [
                _ControlsButton(
                  icon: value.isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: () {
                    value.isPlaying
                        ? widget.controller.pause()
                        : widget.controller.play();
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: context.textTheme.bodySmall!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _ControlsButton(
                  icon: value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                  onPressed: () {
                    widget.controller.setVolume(value.volume > 0 ? 0.0 : 1.0);
                  },
                ),
                const SizedBox(width: 4),
                _ControlsButton(
                  icon: widget.isFullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  onPressed: widget.onToggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSlider(
    VideoPlayerValue value,
    Duration position,
    Duration duration,
    Duration buffered,
  ) {
    final maxMs = duration.inMilliseconds.clamp(1, double.maxFinite.toInt());
    final positionMs = position.inMilliseconds.clamp(0, maxMs).toDouble();
    final bufferedMs = buffered.inMilliseconds.clamp(0, maxMs).toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Theme.of(context).colorScheme.primary,
        inactiveTrackColor: Colors.white30,
        thumbColor: Theme.of(context).colorScheme.primary,
        overlayColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.2),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // 已在后台缓冲。
          LinearProgressIndicator(
            value: duration.inMilliseconds > 0 ? bufferedMs / maxMs : 0,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white38),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          // 拖动进度滑块。
          Slider(
            value: positionMs,
            max: maxMs.toDouble(),
            onChanged: value.isInitialized
                ? (ms) {
                    setState(() {
                      _dragging = true;
                      _dragPosition = Duration(milliseconds: ms.toInt());
                    });
                  }
                : null,
            onChangeEnd: value.isInitialized
                ? (ms) {
                    final target = Duration(milliseconds: ms.toInt());
                    widget.controller.seekTo(target);
                    setState(() => _dragging = false);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final hours = d.inHours;
    final mmss =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$mmss' : mmss;
  }
}

/// fvp 覆盖层内部使用的紧凑圆形控制按钮。
class _ControlsButton extends StatelessWidget {
  const _ControlsButton({
    required this.icon,
    required this.onPressed,
    this.size = 24,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

// ============================================================
// ffplay 面板（Windows 验证后端）
// ============================================================

/// 持有 [FfplayDecoder] 生命周期并显示其状态。
///
/// ffplay 在自己的系统窗口中渲染，因此该面板只负责把解码器接到帧流并报告状态；
/// 应用内不会显示视频。
class _FfplayPanel extends ConsumerStatefulWidget {
  const _FfplayPanel();

  @override
  ConsumerState<_FfplayPanel> createState() => _FfplayPanelState();
}

class _FfplayPanelState extends ConsumerState<_FfplayPanel> {
  @override
  void initState() {
    super.initState();
    // 首帧之后再附加，确保 Provider 已经准备好。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final decoder = ref.read(ffplayDecoderProvider);
      final service = ref.read(videoStreamServiceProvider);
      decoder.attach(service.frameStream);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // 停止喂数据，但保留 Provider 跨重建存活。
    ref.read(ffplayDecoderProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoder = ref.read(ffplayDecoderProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _statusItems(
                context,
                decoder.hasStarted,
                decoder.resolvedPath,
                decoder.lastError,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _statusItems(
    BuildContext context,
    bool hasStarted,
    String? resolvedPath,
    String? lastError,
  ) {
    return [
      Icon(
        Icons.open_in_new,
        size: 56,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
      ),
      const SizedBox(height: 16),
      Text(
        'ffplay 在独立窗口播放',
        style: context.textTheme.titleMedium!.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        hasStarted
            ? '已收到关键帧，ffplay 正在解码。\n若 ffplay 窗口出图，说明拼包正确。'
            : '等待含 VPS/SPS/PPS 的关键帧后启动 ffplay…',
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'ffplay 路径: ${resolvedPath ?? "查找中"}',
        textAlign: TextAlign.center,
        style: context.textTheme.labelSmall!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      if (lastError != null) ...[
        const SizedBox(height: 8),
        Text(
          lastError,
          textAlign: TextAlign.center,
          style: context.textTheme.labelSmall!.copyWith(color: Colors.orange),
        ),
      ],
    ];
  }
}

// ============================================================
// 预览占位（未监听时显示）
// ============================================================

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.isListening});

  final bool isListening;

  @override
  Widget build(BuildContext context) {
    if (!isListening) {
      return const VideoPlaceholderCard(
        title: '未接收视频流',
        subtitle: '点击播放按钮开始接收 UDP 3334 图传',
      );
    }
    return const VideoPlaceholderCard(
      title: '正在接收，等待画面…',
      subtitle: 'TCP 桥已就绪，等待完整视频帧',
      loading: true,
    );
  }
}

// ============================================================
// 侧边面板内容（基础信息和开发者调试区）
// ============================================================

/// 侧边面板中始终可见的基础连接信息。
class _BasicInfo extends StatelessWidget {
  const _BasicInfo({
    required this.isListening,
    required this.frame,
    required this.url,
  });

  final bool isListening;
  final VideoFrame? frame;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VideoStatusRow(isRunning: isListening, runningLabel: '正在接收 (UDP 3334)'),
        context.sizedBox(h: 8),
        ..._buildFrameInfo(),
      ],
    );
  }

  List<Widget> _buildFrameInfo() {
    if (!isListening) {
      return [const VideoInfoRow(label: '状态', value: '未开始接收')];
    }
    if (frame == null) {
      return [
        VideoInfoRow(label: 'TCP 桥地址', value: url ?? '—'),
        const VideoInfoRow(label: '帧', value: '尚未收到完整帧'),
      ];
    }
    final f = frame!;
    return [
      VideoInfoRow(label: 'TCP 桥地址', value: url ?? '—'),
      VideoInfoRow(label: '帧 ID', value: '${f.frameId}'),
      VideoInfoRow(label: '分片数', value: '${f.packetCount}'),
      VideoInfoRow(label: '帧大小', value: _formatBytes(f.annexbData.length)),
      VideoInfoRow(
        label: '重组耗时',
        value: '${f.reassemblyTime.inMilliseconds} ms',
      ),
    ];
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }
}
