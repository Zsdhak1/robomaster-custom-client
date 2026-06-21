/// media_kit (libmpv) decoder for the custom H.264 line (0x0310).
///
/// Mirrors the official line's media_kit player but forces the RAW H.264
/// demuxer (`demuxer-lavf-format=h264`) instead of hevc. NOTE: media_kit's
/// bundled libmpv may not ship the raw-H.264 lavf demuxer on every platform; if
/// it does not, this surfaces libmpv's real error in the overlay (useful as an
/// explicit A/B comparison against fvp), rather than silently showing white.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../logic/custom_video_providers.dart';
import 'crosshair_painter.dart';

/// Decodes the custom raw-H.264 TCP bridge with libmpv and overlays the
/// crosshair.
class CustomMediaKitPlayer extends ConsumerStatefulWidget {
  /// Creates a [CustomMediaKitPlayer] reading from [url].
  const CustomMediaKitPlayer({
    required this.url,
    required this.tsWrap,
    super.key,
  });

  /// The `tcp://127.0.0.1:<port>` bridge URL.
  final String url;

  /// When true the bridge serves MPEG-TS (which libmpv CAN demux); the forced
  /// demuxer is `mpegts` instead of the unsupported raw `h264`.
  final bool tsWrap;

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

  /// Mirrors libmpv's live state (error / playing / buffering / resolution)
  /// into [customVideoDecoderInfoProvider] for the debug panel.
  void _attachDiagnostics() {
    final info = ref.read(customVideoDecoderInfoProvider.notifier);
    int? width;
    int? height;
    _subs
      ..add(_player.stream.error.listen((msg) {
        debugPrint('[custom media_kit error] $msg');
        info.setError(msg);
        if (mounted) setState(() => _error = msg);
      }))
      ..add(_player.stream.playing.listen((p) {
        info.setPlaying(playing: p);
      }))
      ..add(_player.stream.buffering.listen((b) {
        info.setBuffering(buffering: b);
      }))
      ..add(_player.stream.width.listen((w) {
        width = w;
        info.setResolution(width, height);
      }))
      ..add(_player.stream.height.listen((h) {
        height = h;
        info.setResolution(width, height);
      }));
  }

  Future<void> _configureAndOpen() async {
    _attempt++;
    if (mounted) setState(() => _error = null);
    ref
        .read(customVideoDecoderInfoProvider.notifier)
        .beginSession('media_kit', attempt: _attempt);
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        // libmpv refuses tcp:// playlist entries unless this is set first.
        await platform.setProperty('load-unsafe-playlists', 'yes');
        // Force the demuxer (skip probing). libmpv lacks the raw-h264 demuxer,
        // so raw mode will error here ("Unknown lavf format h264"); TS mode
        // forces `mpegts`, which libmpv always ships — that is the whole point
        // of the MPEG-TS wrap for the media_kit backend.
        await platform.setProperty(
          'demuxer-lavf-format',
          widget.tsWrap ? 'mpegts' : 'h264',
        );
        // Raw stream carries no timestamps; assume 60 fps so PTS advance.
        await platform.setProperty('demuxer-lavf-o', 'framerate=60');
        // Low-latency live tuning, matching the official line.
        await platform.setProperty('cache', 'yes');
        await platform.setProperty('demuxer-readahead-secs', '0.5');
        await platform.setProperty('cache-secs', '0.5');
      } on Object catch (e) {
        debugPrint('[custom media_kit] property warning: $e');
      }
    }
    try {
      await _player.open(Media(widget.url));
    } on Object catch (e) {
      ref
          .read(customVideoDecoderInfoProvider.notifier)
          .setError('打开失败: $e');
      if (mounted) setState(() => _error = '打开失败: $e');
    }
  }

  @override
  void didUpdateWidget(covariant CustomMediaKitPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _configureAndOpen();
    }
  }

  @override
  void dispose() {
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
              child: _ErrorBanner(message: _error!, onReconnect: _configureAndOpen),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: _Chip(text: 'media_kit · 第 $_attempt 次'),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
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
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
            TextButton(onPressed: onReconnect, child: const Text('重连')),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }
}
