/// Windows-only ffplay subprocess decoder for verifying frame reassembly.
///
/// Reference client (Python) uses minimal flags and pipes raw HEVC frames
/// into ffplay stdin. The proven working command is:
///
///   ffplay -fflags nobuffer -framedrop -framerate 60
///          -x 640 -y 360 -window_title "..."
///          -f hevc -i -
///
/// CRITICAL architectural difference from the Python reference:
/// Python's subprocess.Popen() is synchronous — the process is alive
/// when the call returns, so buffered frames are flushed immediately.
/// Dart's Process.start() is asynchronous — _proc is null until the
/// Future completes. Our previous code checked _proc immediately after
/// _launch() (fire-and-forget) and found it null, so all pending frames
/// were silently discarded. That left ffplay with an empty stdin and
/// nothing to decode.
library;

import 'dart:async';
import 'dart:io';

import '../core/video/video_frame.dart';

/// Spawns and feeds an ffplay process from a HEVC frame stream (Windows).
///
/// Mirrors the reference client's proven minimal-flag approach, with the
/// crucial fix that pending frames are flushed *after* Process.start()
/// resolves, not before.
class FfplayDecoder {
  Process? _proc;
  StreamSubscription<VideoFrame>? _sub;
  final List<List<int>> _pending = [];
  bool _started = false;

  /// Guards against double-launch if two keyframes arrive back-to-back
  /// before Process.start() resolves.
  bool _launching = false;

  /// Max frames buffered while waiting for the first keyframe.
  ///
  /// Reference client uses 5; we match it for the fastest possible
  /// startup once a keyframe arrives.
  static const int _maxPending = 5;

  /// Whether an ffplay process is currently running.
  bool get isRunning => _proc != null;

  /// Whether the keyframe gate has opened and frames are flowing.
  bool get hasStarted => _started;

  /// Resolved ffplay path, or null if not yet located.
  String? resolvedPath;

  /// Last error message, if startup failed.
  String? lastError;

  /// Candidate locations to search for ffplay, in priority order.
  ///
  /// Resolved via PATH (no hard-coded machine paths, so the build stays
  /// portable). `ffplay.exe` is tried first on Windows; bare `ffplay` covers
  /// Unix-like systems. ffplay is a Windows-only verification backend in the
  /// UI, but the lookup itself stays platform-neutral.
  static const List<String> _candidatePaths = [
    'ffplay.exe',
    'ffplay',
  ];

  /// Locates an ffplay executable, preferring an explicit one if provided.
  String _findFfplay(String? explicitPath) {
    if (explicitPath != null && File(explicitPath).existsSync()) {
      return explicitPath;
    }
    for (final p in _candidatePaths) {
      // Bare names are deferred to PATH resolution by Process.start.
      if (!p.contains(Platform.pathSeparator) || File(p).existsSync()) {
        return p;
      }
    }
    return 'ffplay';
  }

  /// Subscribes to [frameStream] and renders it via an ffplay subprocess.
  ///
  /// [explicitPath] overrides path discovery. Frames are buffered until one
  /// carrying VPS/SPS/PPS arrives, then ffplay is launched and the buffer is
  /// flushed — guaranteeing the decoder sees parameter sets first.
  void attach(Stream<VideoFrame> frameStream, {String? explicitPath}) {
    resolvedPath = _findFfplay(explicitPath);
    _sub = frameStream.listen(_onFrame);
  }

  void _onFrame(VideoFrame frame) {
    final data = frame.annexbData;
    if (!_started) {
      _pending.add(data);
      if (_pending.length > _maxPending) _pending.removeAt(0);
      if (_hasParameterSet(data) && !_launching) {
        _launching = true;
        // Fire-and-forget: _launch() is async; pending frames are flushed
        // inside it once the process is actually alive.
        _launch();
      }
      return;
    }
    _write(data);
  }

  /// Returns true if [data] contains VPS, SPS or PPS NAL units.
  bool _hasParameterSet(List<int> data) {
    const vps = 32, sps = 33, pps = 34;
    final n = data.length;
    var i = 0;
    while (i + 3 < n) {
      final isLong = data[i] == 0 &&
          data[i + 1] == 0 &&
          data[i + 2] == 0 &&
          data[i + 3] == 1;
      final isShort = data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1;
      if (isLong || isShort) {
        final hdr = i + (isLong ? 4 : 3);
        if (hdr < n) {
          final nalType = (data[hdr] >> 1) & 0x3F;
          if (nalType == vps || nalType == sps || nalType == pps) {
            return true;
          }
        }
        i = hdr;
      } else {
        i++;
      }
    }
    return false;
  }

  /// Starts ffplay and flushes the pending frame buffer once the process
  /// is actually alive.
  ///
  /// This is the key fix: in the old code _launch() was fire-and-forget,
  /// and the caller checked _proc immediately (it was still null). All
  /// pending frames were dropped. Now we await Process.start(), set _proc,
  /// flush pending, and only then mark _started = true.
  Future<void> _launch() async {
    if (_proc != null) return;
    final path = resolvedPath ?? 'ffplay';
    // Minimal flags matching the proven reference client.
    // Do NOT add -threads, -hwaccel, -probesize, -analyzeduration,
    // -hide_banner or -loglevel — those are ffmpeg-only flags.
    final args = <String>[
      '-fflags', 'nobuffer',
      '-framedrop',
      '-framerate', '60',
      '-x', '640',
      '-y', '360',
      '-window_title', 'RMU 图传 (ffplay 验证)',
      '-f', 'hevc',
      '-i', '-',
    ];
    try {
      final proc = await Process.start(path, args);
      _proc = proc;

      // CRITICAL FIX: flush pending frames NOW, while _proc is alive.
      // Old code did this check immediately after fire-and-forget
      // _launch() and found _proc == null — frames were silently lost.
      for (final f in _pending) {
        _write(f);
      }
      _pending.clear();
      _started = true;

      unawaited(proc.exitCode.then((code) {
        _proc = null;
        _started = false;
        _launching = false;
        if (code != 0 && code != -1) {
          lastError = 'ffplay 退出码: $code';
        }
      }));
    } on Object catch (e) {
      lastError = '启动 ffplay 失败: $e';
      _launching = false;
    }
  }

  void _write(List<int> data) {
    final proc = _proc;
    if (proc == null) return;
    try {
      proc.stdin.add(data);
    } on Object catch (_) {
      // Pipe closed — process likely exited; ignore.
    }
  }

  /// Stops feeding and terminates the ffplay process.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _pending.clear();
    _started = false;
    _launching = false;
    final proc = _proc;
    _proc = null;
    if (proc != null) {
      try {
        proc.stdin.close();
      } on Object catch (_) {}
      proc.kill();
    }
  }

  /// Releases all resources.
  void dispose() => stop();
}
