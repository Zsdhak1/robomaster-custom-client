/// Launches an external `ffplay` process to verify the custom H.264 line.
///
/// Unlike the official line's [FfplayDecoder] (which pipes HEVC frames into
/// ffplay's stdin), the custom line already exposes its reassembled Annex-B
/// stream over a loopback TCP server ([AnnexbTcpServer]). So ffplay can connect
/// to that URL directly — exactly the proven manual command:
///
///   ffplay -f h264 tcp://127.0.0.1:PORT
///
/// This is a Windows-oriented verification aid: if ffplay's own window shows the
/// picture while the in-app fvp/media_kit backend stays white, the bug is in the
/// in-app decoder config, not in the byte stream the bridge serves.
library;

import 'dart:async';
import 'dart:io';

/// Spawns and tears down an `ffplay` subprocess pointed at the bridge URL.
class CustomFfplayLauncher {
  Process? _proc;

  /// Resolved ffplay executable, or null until [start] runs.
  String? resolvedPath;

  /// Last error message, if launch failed or ffplay exited abnormally.
  String? lastError;

  /// Whether an ffplay process is currently running.
  bool get isRunning => _proc != null;

  /// Candidate executable names, resolved against PATH by [Process.start].
  static const List<String> _candidates = ['ffplay.exe', 'ffplay'];

  /// Launches `ffplay -f <fmt> -i <streamUrl>`. Idempotent while running.
  ///
  /// [tsWrap] selects the input format: `mpegts` when the bridge serves TS,
  /// else raw `h264`.
  Future<void> start(String streamUrl, {required bool tsWrap}) async {
    if (_proc != null) return;
    lastError = null;
    final path = _findFfplay();
    resolvedPath = path;
    final format = tsWrap ? 'mpegts' : 'h264';
    // Minimal low-latency flags, mirroring the proven manual command. ffplay
    // connects to the TCP bridge as just another decoder client; the bridge
    // primes it with the cached keyframe so it can start without an 8 s wait.
    final args = <String>[
      '-fflags', 'nobuffer',
      '-flags', 'low_delay',
      '-framedrop',
      '-framerate', '60',
      '-window_title', '自定义图传 (ffplay 验证)',
      '-f', format,
      '-i', streamUrl,
    ];
    try {
      final proc = await Process.start(path, args);
      _proc = proc;
      unawaited(proc.exitCode.then((code) {
        _proc = null;
        if (code != 0 && code != -1) {
          lastError = 'ffplay 退出码: $code';
        }
      }));
    } on Object catch (e) {
      lastError = '启动 ffplay 失败: $e';
    }
  }

  /// Terminates the ffplay process, if any.
  void stop() {
    final proc = _proc;
    _proc = null;
    proc?.kill();
  }

  /// Releases all resources.
  void dispose() => stop();

  String _findFfplay() {
    for (final p in _candidates) {
      if (!p.contains(Platform.pathSeparator) || File(p).existsSync()) {
        return p;
      }
    }
    return 'ffplay';
  }
}
