/// Video-stream monitoring panel with real decoder rendering.
///
/// Supports two backends:
///  • media_kit (libmpv) — selected via [videoDecoderBackendProvider]
///  • fvp (libmdk via video_player) — selected via the same provider
///
/// Both consume the AnnexB stream from the local loopback TCP bridge.
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
import '../../../../core/widgets/video_side_panel.dart';
import '../../../settings/logic/settings_providers.dart';
import '../../logic/stream_providers.dart';
import 'video_debug_panel.dart';

/// Panel body of the video screen: real player + stream stats.
class VideoPanel extends ConsumerWidget {
  /// Creates a [VideoPanel].
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

    return Padding(
      padding: context.insetAll(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: isListening && url != null
                ? _buildPlayer(url, backend, hwdec, developerMode: developerMode)
                : _PreviewPlaceholder(
                    isListening: isListening,
                  ),
          ),
          context.sizedBox(w: 12),
          Expanded(
            child: VideoSidePanel(
              title: '视频流状态',
              developerMode: developerMode,
              basicInfo: _BasicInfo(
                isListening: isListening,
                frame: latestFrame,
                url: url,
              ),
              debugSection: const _DebugSection(),
            ),
          ),
        ],
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
// media_kit player
// ============================================================

class _MediaKitPlayer extends StatefulWidget {
  const _MediaKitPlayer({
    required this.url,
    required this.hwdec,
    required this.developerMode,
  });

  final String url;

  /// libmpv `hwdec` property value (e.g. 'auto-safe', 'd3d11va', 'no').
  final String hwdec;

  /// When false, the overlay shows only a reconnect button.
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

  /// Last error reported by libmpv, shown as an overlay.
  String? _lastError;

  /// Whether libmpv has started decoding/playing frames.
  bool _playing = false;

  /// How many times we've (re)opened the stream this session.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    // logLevel: warn surfaces libmpv's connection/demuxer diagnostics so we
    // can see WHY a decoder fails to attach to the TCP bridge (the default
    // `error` level hides "Connection failed"/"Failed to open" lines).
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );
    _controller = VideoController(_player);

    // Surface libmpv's real failure reason instead of silently swallowing it.
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

  /// Configures libmpv, then opens the stream.
  ///
  /// The decisive fix is `load-unsafe-playlists=yes`: media_kit loads URLs via
  /// a temp playlist + `loadlist`, and libmpv refuses tcp:// playlist entries
  /// by default — that is why the decoder never connected. The rest mirrors
  /// VLC's proven `:demux=hevc :network-caching=1000` setup.
  Future<void> _configureAndOpen() async {
    _attempt++;
    if (mounted) setState(() => _lastError = null);
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        // ROOT CAUSE of "decoder connections: 0": media_kit's open() does
        // not loadfile the URL directly — it writes the URL into a temp
        // playlist and runs `loadlist`. libmpv then refuses the tcp:// entry
        // ("Refusing to load potentially unsafe URL from a playlist") and
        // never even opens the stream, so the bridge sees zero clients.
        // This MUST be set before open() (which runs loadlist internally).
        await platform.setProperty('load-unsafe-playlists', 'yes');
        // = VLC :demux=hevc — force the raw-HEVC demuxer (skip probing).
        await platform.setProperty('demuxer-lavf-format', 'hevc');
        // Raw stream has no timestamps; assume 60 fps so PTS advance.
        await platform.setProperty('demuxer-lavf-o', 'framerate=60');
        // = VLC :network-caching=1000 — buffer ~1s so the demuxer has
        // enough bytes to lock on. The old `cache=no` was the root cause
        // of media_kit showing nothing while VLC worked.
        await platform.setProperty('cache', 'yes');
        await platform.setProperty('demuxer-readahead-secs', '0.3');
        await platform.setProperty('cache-secs', '0.3');
        // User-selected hardware decoder. mpv falls back to software decode
        // automatically if the chosen mode is unsupported on this platform.
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

  /// Tears down the current stream and reopens it from scratch.
  ///
  /// Use when the decoder failed to connect or the stream stalled — this
  /// forces libmpv to drop its state and reconnect to the TCP bridge,
  /// re-triggering the keyframe gate.
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
    // Reopen on URL change OR hwdec change (hwdec only takes effect on load).
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

/// Status chip + reconnect control overlaid on the media_kit video.
///
/// When [developerMode] is off, only a compact reconnect button is shown
/// (普通用户也能手动重连); the status light, attempt counter and error detail
/// are developer-only.
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
      // Keep only the reconnect affordance for end users.
      return _pill(child: _reconnectButton());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildStatusChip(),
        if (error != null) _buildErrorBox(),
      ],
    );
  }

  Widget _reconnectButton() {
    return InkWell(
      onTap: onReconnect,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, color: Colors.white, size: 14),
          SizedBox(width: 2),
          Text('重连', style: TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
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
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          const SizedBox(width: 8),
          _reconnectButton(),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: _pill(
          child: Text(
            error!,
            style: const TextStyle(color: Colors.orange, fontSize: 10),
          ),
        ),
      ),
    );
  }

  /// Translucent rounded container shared by the status chip and error box.
  Widget _pill({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      ),
    );
  }
}

// ============================================================
// fvp player (via video_player)
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
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      }).catchError((Object e) {
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
          : const ColoredBox(
              color: Color(0xFF101418),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      '正在初始化 fvp 播放器…',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
    );

    if (_isFullscreen) {
      // Hide the surrounding Row/Padding when in fullscreen so the video fills
      // the whole screen. The caller still owns the state, so we rebuild in
      // place; the Scaffold is underneath and its appBar/FAB auto-hide via the
      // system UI modes above.
      player = Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: player),
      );
    }

    return player;
  }

  Widget _buildError() {
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
                const SizedBox(height: 8),
                const Text(
                  'fvp 可能不支持 tcp:// 协议，请尝试切换到 media_kit',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay controls for the fvp backend: play/pause, seek, time, mute, fullscreen.
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
  /// Whether the user is currently dragging the progress bar.
  bool _dragging = false;

  /// The value during drag, overriding the controller's position.
  Duration _dragPosition = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        final showBigPlay = value.isInitialized && !value.isPlaying && !value.isBuffering;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Tapping the video toggles play/pause.
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
            Colors.black.withValues(alpha: 0.7),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _ControlsButton(
                  icon: value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                  onPressed: () {
                    widget.controller
                        .setVolume(value.volume > 0 ? 0.0 : 1.0);
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
        overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Buffered background.
          LinearProgressIndicator(
            value: duration.inMilliseconds > 0 ? bufferedMs / maxMs : 0,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white38),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
          // Seek slider.
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
    final mmss = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$mmss' : mmss;
  }
}

/// Compact circular control button used inside the fvp overlay.
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
// ffplay panel (Windows verification backend)
// ============================================================

/// Hosts the [FfplayDecoder] lifecycle and shows its status.
///
/// ffplay renders in its own OS window, so this panel only attaches the
/// decoder to the frame stream and reports state — there is no in-app video.
class _FfplayPanel extends ConsumerStatefulWidget {
  const _FfplayPanel();

  @override
  ConsumerState<_FfplayPanel> createState() => _FfplayPanelState();
}

class _FfplayPanelState extends ConsumerState<_FfplayPanel> {
  @override
  void initState() {
    super.initState();
    // Attach after first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final decoder = ref.read(ffplayDecoderProvider);
      final service = ref.read(videoStreamServiceProvider);
      decoder.attach(service.frameStream);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Stop feeding but keep the provider alive across rebuilds.
    ref.read(ffplayDecoderProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decoder = ref.read(ffplayDecoderProvider);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: const Color(0xFF101418),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _statusItems(
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
    bool hasStarted,
    String? resolvedPath,
    String? lastError,
  ) {
    return [
      const Icon(Icons.open_in_new, size: 56, color: Colors.white38),
      const SizedBox(height: 16),
      const Text(
        'ffplay 在独立窗口播放',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        hasStarted
            ? '已收到关键帧，ffplay 正在解码。\n若 ffplay 窗口出图，说明拼包正确。'
            : '等待含 VPS/SPS/PPS 的关键帧后启动 ffplay…',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      ),
      const SizedBox(height: 12),
      Text(
        'ffplay 路径: ${resolvedPath ?? "查找中"}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white30, fontSize: 11),
      ),
      if (lastError != null) ...[
        const SizedBox(height: 8),
        Text(
          lastError,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.orange, fontSize: 11),
        ),
      ],
    ];
  }
}

// ============================================================
// Preview placeholder (shown when not listening)
// ============================================================

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.isListening});

  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: const Color(0xFF101418),
        child: Center(child: _buildContent()),
      ),
    );
  }

  Widget _buildContent() {
    if (!isListening) {
      return _placeholder(
        icon: Icons.videocam_off,
        title: '未接收视频流',
        subtitle: '点击右上角播放按钮开始接收 UDP 3334 数据',
      );
    }
    return _placeholder(
      icon: Icons.hourglass_empty,
      title: '正在等待视频帧…',
      subtitle: 'TCP 桥已就绪，等待 UDP 帧到达',
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Side-panel content (basic info + dev-only debug section)
// ============================================================

/// Always-visible basic connection info for the side panel.
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
        _StatusRow(isListening: isListening),
        context.sizedBox(h: 8),
        ..._buildFrameInfo(),
      ],
    );
  }

  List<Widget> _buildFrameInfo() {
    if (!isListening) {
      return [
        const _InfoRow(label: '状态', value: '未开始接收'),
      ];
    }
    if (frame == null) {
      return [
        _InfoRow(label: 'TCP 桥地址', value: url ?? '—'),
        const _InfoRow(label: '帧', value: '尚未收到完整帧'),
      ];
    }
    final f = frame!;
    return [
      _InfoRow(label: 'TCP 桥地址', value: url ?? '—'),
      _InfoRow(label: '帧 ID', value: '${f.frameId}'),
      _InfoRow(label: '分片数', value: '${f.packetCount}'),
      _InfoRow(label: '帧大小', value: _formatBytes(f.annexbData.length)),
      _InfoRow(
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

/// Developer-only debug section wrapping the dark debug content.
class _DebugSection extends StatelessWidget {
  const _DebugSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: context.insetAll(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: const VideoDebugContent(),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.isListening});

  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final color = isListening ? Colors.green : Colors.grey;
    return Row(
      children: [
        Container(
          width: context.rmStatusDotSize,
          height: context.rmStatusDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        context.sizedBox(w: 8),
        Text(
          isListening ? '正在接收 (UDP 3334)' : '已停止',
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
