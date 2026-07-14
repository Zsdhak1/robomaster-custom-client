/// 仅用于 Windows 验证帧重组的 ffplay 子进程解码器。
///
/// 参考客户端（Python）使用最小参数，并将原始 HEVC 帧写入 ffplay 标准输入。
/// 已验证可工作的命令如下：
///
///   ffplay -fflags nobuffer -framedrop -framerate 60
///          -x 640 -y 360 -window_title "..."
///          -f hevc -i -
///
/// 与 Python 参考实现的关键差异在于：`subprocess.Popen()` 是同步的，调用返回时
/// 进程已经存活，因此可以立刻刷新缓冲帧；Dart 的 `Process.start()` 是异步的，
/// `_proc` 要等 Future 完成后才会赋值。旧代码触发 `_launch()` 后立即检查 `_proc`，
/// 此时仍为 null，导致等待中的帧被静默丢弃，ffplay 只拿到空标准输入。
library;

import 'dart:async';
import 'dart:io';

import '../core/video/video_frame.dart';

/// 从 HEVC 帧流启动并喂给一个 ffplay 进程（Windows 验证用途）。
///
/// 保持与参考客户端一致的最小参数方案，并确保等待中的帧只在 `Process.start()`
/// 完成、进程真实存活后刷新。
class FfplayDecoder {
  Process? _proc;
  StreamSubscription<VideoFrame>? _sub;
  final List<List<int>> _pending = [];
  bool _started = false;

  /// 防止两个关键帧在 `Process.start()` 完成前连续到达而重复启动进程。
  bool _launching = false;

  /// 等待首个关键帧期间最多缓冲的帧数。
  ///
  /// 参考客户端使用 5；这里保持一致，以便关键帧到达后尽快启动。
  static const int _maxPending = 5;

  /// 当前是否有 ffplay 进程正在运行。
  bool get isRunning => _proc != null;

  /// 关键帧闸门是否已打开，后续帧是否已开始流入。
  bool get hasStarted => _started;

  /// 解析后的 ffplay 路径；尚未定位时为 null。
  String? resolvedPath;

  /// 最近一次启动失败的错误消息。
  String? lastError;

  /// 按优先级排列的 ffplay 候选路径。
  ///
  /// 通过 PATH 解析，不硬编码机器路径，因此构建保持可移植。Windows 优先尝试
  /// `ffplay.exe`，裸 `ffplay` 覆盖类 Unix 系统。虽然 UI 中 ffplay 只是 Windows
  /// 验证后端，但查找逻辑本身保持平台中立。
  static const List<String> _candidatePaths = [
    'ffplay.exe',
    'ffplay',
  ];

  /// 定位 ffplay 可执行文件；如果提供显式路径则优先使用。
  String _findFfplay(String? explicitPath) {
    if (explicitPath != null && File(explicitPath).existsSync()) {
      return explicitPath;
    }
    for (final p in _candidatePaths) {
      // 裸命令名交给 Process.start 走 PATH 解析。
      if (!p.contains(Platform.pathSeparator) || File(p).existsSync()) {
        return p;
      }
    }
    return 'ffplay';
  }

  /// 订阅 [frameStream] 并通过 ffplay 子进程渲染。
  ///
  /// [explicitPath] 会覆盖自动路径查找。帧会先缓冲，直到携带 VPS/SPS/PPS 的关键帧
  /// 到达后再启动 ffplay 并刷新缓冲区，保证解码器最先看到参数集。
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
        // 触发后不等待；_launch() 是异步的，等待中帧会在进程真实存活后由它刷新。
        _launch();
      }
      return;
    }
    _write(data);
  }

  /// 当 [data] 包含 VPS、SPS 或 PPS NAL 单元时返回 true。
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

  /// 启动 ffplay，并在进程真实存活后刷新等待中的帧缓冲区。
  ///
  /// 这是关键修复：旧代码对 `_launch()` 触发后不等待，调用方又立刻检查 `_proc`
  /// （此时仍为 null），导致所有等待帧被丢弃。现在等待 `Process.start()` 完成，
  /// 先设置 `_proc`，再刷新等待帧，最后才标记 `_started = true`。
  Future<void> _launch() async {
    if (_proc != null) return;
    final path = resolvedPath ?? 'ffplay';
    // 最小参数匹配已验证的参考客户端。
    // 不要添加 -threads、-hwaccel、-probesize、-analyzeduration、
    // -hide_banner 或 -loglevel；这些是 ffmpeg 参数，不适合这里。
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

      // 关键修复：只有 _proc 存活后才刷新等待帧。
      // 旧代码触发 _launch() 后立刻检查 _proc，看到 null 后就静默丢帧。
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
      // 管道已关闭，通常表示进程已经退出；忽略即可。
    }
  }

  /// 停止喂帧并终止 ffplay 进程。
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

  /// 释放所有资源。
  void dispose() => stop();
}
