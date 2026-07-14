/// 启动外部 `ffplay` 进程，用于验证自定义图传链路。
///
/// 与官方链路的 [FfplayDecoder] 不同，自定义链路已经通过回环 TCP 服务器
/// [AnnexbTcpServer] 暴露重组后的 AnnexB 流，因此 ffplay 可以直接连接 URL。
/// 已验证的手动命令如下：
///
///   ffplay -f h264 tcp://127.0.0.1:端口        (H.264)
///   ffplay -f hevc tcp://127.0.0.1:端口        (HEVC / H.265)
///
/// 这是偏 Windows 的验证工具：如果 ffplay 独立窗口能显示画面，而应用内
/// fvp/media_kit 后端仍是白屏，问题通常在应用内解码器配置，而不是桥接服务的字节流。
library;

import 'dart:async';
import 'dart:io';

import '../../settings/logic/settings_providers.dart';

/// 启动并停止指向桥接 URL 的 `ffplay` 子进程。
class CustomFfplayLauncher {
  Process? _proc;

  /// 解析后的 ffplay 可执行文件路径；[start] 运行前为 null。
  String? resolvedPath;

  /// 最近一次启动失败或 ffplay 异常退出的错误消息。
  String? lastError;

  /// 当前是否有 ffplay 进程正在运行。
  bool get isRunning => _proc != null;

  /// 候选可执行文件名，由 [Process.start] 通过 PATH 解析。
  static const List<String> _candidates = ['ffplay.exe', 'ffplay'];

  /// 启动 `ffplay -f <fmt> -i <streamUrl>`；运行中重复调用无效。
  ///
  /// [tsWrap] 选择输入格式：桥接输出 TS 时为 `mpegts`，否则根据 [codec]
  /// 使用原始 `h264` 或 `hevc`。
  Future<void> start(
    String streamUrl, {
    required bool tsWrap,
    CustomVideoCodec codec = CustomVideoCodec.h264,
  }) async {
    if (_proc != null) return;
    lastError = null;
    final path = _findFfplay();
    resolvedPath = path;
    final format = tsWrap
        ? 'mpegts'
        : codec == CustomVideoCodec.h265
            ? 'hevc'
            : 'h264';
    // 最小低延迟参数，匹配已验证的手动命令。ffplay 只是另一个 TCP 桥接客户端；
    // 桥接会用已缓存的关键帧预热它，避免等待一个完整 GOP。
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

  /// 终止 ffplay 进程（如果存在）。
  void stop() {
    final proc = _proc;
    _proc = null;
    proc?.kill();
  }

  /// 释放所有资源。
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
