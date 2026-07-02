/// media_kit (libmpv) decoder for the custom video line (0x0310).
///
/// Mirrors the official line's media_kit player but forces the RAW codec
/// demuxer (`demuxer-lavf-format=h264` or `=hevc`).  NOTE: media_kit's
/// bundled libmpv may not ship the raw-H.264 lavf demuxer on every platform;
/// if it does not, this surfaces libmpv's real error in the overlay (useful as
/// an explicit A/B comparison against fvp), rather than silently showing white.
/// The MPEG-TS wrapper (`tsWrap`) works around that limitation for both codecs.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/widgets/video_overlay_controls.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_video_providers.dart';
import 'crosshair_painter.dart';

/// Decodes the custom raw-video TCP bridge with libmpv and overlays the
/// crosshair.
class CustomMediaKitPlayer extends ConsumerStatefulWidget {
  /// Creates a [CustomMediaKitPlayer] reading from [url].
  const CustomMediaKitPlayer({
    required this.url,
    required this.tsWrap,
    required this.codec,
    super.key,
  });

  /// The `tcp://127.0.0.1:<port>` bridge URL.
  final String url;

  /// When true the bridge serves MPEG-TS (which libmpv CAN demux); the forced
  /// demuxer is `mpegts` instead of the raw codec format.
  final bool tsWrap;

  /// The video codec: H.264 → `h264`, H.265 → `hevc`.
  final CustomVideoCodec codec;

  @override
  ConsumerState<CustomMediaKitPlayer> createState() =>
      _CustomMediaKitPlayerState();
}

class _CustomMediaKitPlayerState extends ConsumerState<CustomMediaKitPlayer> {
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<Object?>> _subs = [];
  String? _error;
  int _attempt = 0;
  Offset? _crosshairCenter;

  /// Auto-reconnect watchdog — see [_FvpPlayerState] for the full rationale.
  ///
  /// The player is created the instant the keyframe gate opens, racing the
  /// just-started stream; a first attempt that probes before enough data has
  /// landed used to strand the user on the error banner until they tapped 重连.
  /// This watchdog retries automatically (bounded) until playback begins.
  Timer? _connectWatchdog;

  /// Whether libmpv has reported it is actually playing (our success signal).
  bool _playing = false;

  /// Auto-retries used since the last successful connect.
  int _autoRetries = 0;

  /// Max automatic reconnect attempts before waiting for a manual 重连.
  static const int _maxAutoRetries = 8;

  /// How long a connect attempt may go without playback before we retry.
  static const Duration _connectTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _controller = VideoController(_player);
    _attachDiagnostics();
    _configureAndOpen();
  }

  /// Fires when a connect attempt hasn't started playing in time; retries
  /// (bounded) so a first attempt that raced the stream start self-heals.
  void _onConnectTimeout() {
    if (!mounted || _playing) return;
    if (_autoRetries >= _maxAutoRetries) return;
    _autoRetries++;
    _reconnect(auto: true);
  }

  /// Mirrors libmpv's live state (error / playing / buffering / resolution)
  /// into [customVideoDecoderInfoProvider] for the debug panel.
  void _attachDiagnostics() {
    final info = ref.read(customVideoDecoderInfoProvider.notifier);
    int? width;
    int? height;
    _subs
      ..add(
        _player.stream.error.listen((msg) {
          debugPrint('[custom media_kit error] $msg');
          info.setError(msg);
          if (mounted) setState(() => _error = msg);
        }),
      )
      ..add(
        _player.stream.playing.listen((p) {
          info.setPlaying(playing: p);
          if (p) {
            // Playback started — cancel the watchdog and clear the retry budget.
            _playing = true;
            _connectWatchdog?.cancel();
            _connectWatchdog = null;
            _autoRetries = 0;
          }
        }),
      )
      ..add(
        _player.stream.buffering.listen((b) {
          info.setBuffering(buffering: b);
        }),
      )
      ..add(
        _player.stream.width.listen((w) {
          width = w;
          info.setResolution(width, height);
        }),
      )
      ..add(
        _player.stream.height.listen((h) {
          height = h;
          info.setResolution(width, height);
        }),
      );
  }

  Future<void> _configureAndOpen() async {
    _attempt++;
    _playing = false;
    if (mounted) setState(() => _error = null);
    // Arm the watchdog: retry automatically if playback doesn't begin in time.
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(_connectTimeout, _onConnectTimeout);
    ref
        .read(customVideoDecoderInfoProvider.notifier)
        .beginSession('media_kit', attempt: _attempt);
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        // libmpv refuses tcp:// playlist entries unless this is set first.
        await platform.setProperty('load-unsafe-playlists', 'yes');
        // Force the demuxer (skip probing).  In raw mode libmpv may lack the
        // raw-h264 demuxer; HEVC raw demuxer is always available in mpv.  TS
        // mode forces `mpegts`, which libmpv always ships — that is the whole
        // point of the MPEG-TS wrap for the media_kit backend.
        await platform.setProperty(
          'demuxer-lavf-format',
          widget.tsWrap
              ? 'mpegts'
              : widget.codec == CustomVideoCodec.h265
              ? 'hevc'
              : 'h264',
        );
        // Low-delay demuxer flags. NOTE: demuxer-lavf-o REPLACES the whole
        // option dict, so everything must go in ONE comma-separated value —
        // a second setProperty('demuxer-lavf-o', …) would wipe the first.
        //
        // CRITICAL probe budget difference by mode:
        // - TS mode: MPEG-TS is a MUX. lavf must read PAT/PMT and probe far
        //   enough to discover the video elementary stream (PID 0x100). Starving
        //   probesize/analyzeduration opens the container but finds NO video
        //   track → black screen. Give it a real budget (~1 MB / a few 100 ms).
        // - Raw mode: the stream is a single ES, nothing to demux, so an
        //   aggressive tiny probe is safe and cuts latency; keep framerate=60 so
        //   the raw ES gets a timeline.
        // +nobuffer / +low_delay are low-latency BUFFERING flags (harmless to
        // probing) and stay in both modes.
        await platform.setProperty(
          'demuxer-lavf-o',
          widget.tsWrap
              ? 'fflags=+nobuffer,flags=+low_delay,'
                  'probesize=1000000,analyzeduration=500000'
              : 'framerate=60,fflags=+nobuffer,flags=+low_delay,'
                  'probesize=32,analyzeduration=0',
        );
        // Live anti-rebuffer tuning (mpv's own [low-latency] profile knobs).
        // The real source frame rate is unstable; the fix is to render frames
        // as they arrive and NEVER enter the pause-to-buffer state on a
        // momentarily dry cache — otherwise every brief starvation becomes a
        // ~1 s freeze/resume loop.
        await platform.setProperty('cache', 'yes'); // needed for mpegts lock-on
        await platform.setProperty('cache-secs', '0'); // no forward-fill target
        await platform.setProperty('demuxer-readahead-secs', '0');
        // *** primary fix: keep rendering instead of pausing to rebuffer.
        await platform.setProperty('cache-pause', 'no');
        await platform.setProperty('cache-pause-initial', 'no'); // no startup stall
        await platform.setProperty('framedrop', 'vo'); // drop stale, don't queue latency
        await platform.setProperty('video-sync', 'audio'); // cheap sync, no resample buffer
        await platform.setProperty('interpolation', 'no');
        await platform.setProperty('video-latency-hacks', 'yes');
        await platform.setProperty('stream-buffer-size', '4k');
      } on Object catch (e) {
        debugPrint('[custom media_kit] property warning: $e');
      }
    }
    try {
      await _player.open(Media(widget.url));
    } on Object catch (e) {
      ref.read(customVideoDecoderInfoProvider.notifier).setError('打开失败: $e');
      if (mounted) setState(() => _error = '打开失败: $e');
    }
  }

  /// Tears down playback and reopens. [auto] marks a watchdog-driven retry;
  /// a manual 重连 (auto=false) resets the auto-retry budget.
  Future<void> _reconnect({bool auto = false}) async {
    if (!auto) _autoRetries = 0;
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
    try {
      await _player.stop();
    } on Object {
      // stop may throw if the player was never fully opened; safe to ignore.
    }
    await _configureAndOpen();
  }

  @override
  void didUpdateWidget(covariant CustomMediaKitPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _reconnect();
    }
  }

  @override
  void dispose() {
    _connectWatchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                setState(() {
                  _crosshairCenter = details.localPosition;
                });
              },
              child: CustomPaint(
                foregroundPainter: CrosshairPainter(
                  aimCenter: _crosshairCenter,
                ),
                child: Video(controller: _controller),
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _ErrorBanner(message: _error!, onReconnect: _reconnect),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: VideoReconnectChip(
              backendLabel: 'media_kit',
              attempt: _attempt,
              onReconnect: _reconnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onReconnect});

  final String message;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall!.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            TextButton(onPressed: onReconnect, child: const Text('重连')),
          ],
        ),
      ),
    );
  }
}
