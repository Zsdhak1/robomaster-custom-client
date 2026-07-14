/// 本地回环 TCP 服务器，用于输出重组后的 HEVC AnnexB 流。
///
/// media_kit / fvp 等解码器通过 URL 播放数据，而应用内持有的是
/// 内存中的 AnnexB 帧。本服务器绑定 `127.0.0.1:<port>`，
/// 接受解码器客户端连接，并按到达顺序写出每帧字节；
/// 拼接后的字节流就是有效的 H.265 elementary stream。
///
/// 关键点：输出必须由关键帧闸门控制。若原始 HEVC 流从 GOP 中间开始，
/// 解码器看不到 VPS/SPS/PPS 参数集，可能永远无法初始化。
/// 因此这里会丢弃关键帧前的帧，直到携带 VPS/SPS/PPS 的帧到达，
/// 再从该关键帧开始连续输出。这与已验证的参考客户端延迟启动策略一致。
/// 不在流中途重新注入参数集，因为这会刷新解码器参考帧缓冲并破坏解码；
/// 原始流本身已经在每个 IDR 前携带这些参数集。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/utils/byte_data_reader.dart';

/// 等待首个关键帧时最多保留的帧数。
const int _maxPendingFrames = 30;

/// 判断 AnnexB 缓冲区是否携带解码所需参数集的函数签名。
///
/// 默认使用 HEVC 检测器 [hevcHasParameterSet]；
/// 自定义图传链路会注入 H.264 检测器，避免两条链路共享 NAL 解析规则。
typedef ParameterSetDetector = bool Function(Uint8List data);

/// 通过回环 TCP 套接字提供连续 AnnexB 字节流。
class AnnexbTcpServer {
  /// 创建使用 [parameterSetDetector] 作为关键帧闸门的服务器。
///
  /// 默认使用 HEVC 检测，保持官方 UDP 3334 视频链路行为不变。
  /// 自定义 0x0310 H.264 链路会改传 [h264HasParameterSet]。
  AnnexbTcpServer({ParameterSetDetector? parameterSetDetector})
      : _detectParameterSet = parameterSetDetector ?? hevcHasParameterSet;

  /// 判断某帧是否打开关键帧闸门的检测器。
  final ParameterSetDetector _detectParameterSet;

  ServerSocket? _server;

  /// 已连接的解码器客户端；帧会广播给所有客户端。
  final List<Socket> _clients = [];

  /// 见到首个关键帧（VPS/SPS/PPS）前暂存的帧。
///
  /// 这些关键帧前帧解码器无法使用，只用于诊断计数；
  /// 闸门打开后会全部丢弃，让流从关键帧干净开始。
  final List<Uint8List> _pending = [];

  /// 是否已经见到关键帧并开始输出流。
  bool _started = false;

  /// 最近一次携带参数集的关键帧。
///
  /// 闸门打开后新连接的解码器会先收到该帧。
  /// 这是常见路径：播放器通常在拿到桥接 URL 后异步接入，
  /// 那时 SPS/PPS+IDR 可能已经被写给空客户端列表并丢失。
///
  /// 这对 fvp/mdk 特别关键：`updateTexture()` 必须先知道视频尺寸，
  /// 而尺寸信息在 SPS 中。实时 TCP 流不可 seek，依靠大探测读取 SPS
  /// 后再回到起点会失败，最终导致关键帧被丢弃并白屏。
  /// 把关键帧放在每个客户端流的最前面，可以立即提供尺寸和可解码 IDR，
  /// 避免探测、seek 以及等待整段 GOP。闸门打开前该值为 null。
  Uint8List? _keyframe;

  /// 服务器当前是否已绑定并监听。
  bool get isRunning => _server != null;

  /// 服务器绑定的端口；未运行时为 null。
  int? get port => _server?.port;

  /// 解码器读取流时应打开的 URL。
///
  /// 服务器未运行时为 null。
  String? get streamUrl {
    final p = _server?.port;
    return p == null ? null : 'tcp://127.0.0.1:$p';
  }

  // --- 调试统计 ---

  /// 当前已连接的解码器客户端数。
  int get clientCount => _clients.length;

  /// 关键帧闸门是否已打开（已见到 VPS/SPS/PPS 帧）。
  bool get hasStarted => _started;

  /// 等待首个关键帧时暂存的帧数。
  int get pendingCount => _pending.length;

  /// 已转发给客户端的 AnnexB 帧总数。
  int framesForwarded = 0;

  /// 已转发给客户端的字节总数。
  int bytesForwarded = 0;

  /// 在临时端口启动回环 TCP 服务器。
  Future<void> start() async {
    if (_server != null) return;

    framesForwarded = 0;
    bytesForwarded = 0;
    _started = false;
    _keyframe = null;
    _pending.clear();

    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

    _server!.listen((socket) {
      _clients.add(socket);
      // 后接入的解码器先补发缓存关键帧，
      // 让它从携带参数集的干净 IDR 开始，而不是从 GOP 中间开始。
      // 闸门打开前这里是空操作；最早接入的客户端会实时收到关键帧。
      _replayKeyframe(socket);
      // 监听客户端关闭和错误，及时清理连接。
      socket.listen(
        (_) {},
        onError: (_) => _removeClient(socket),
        onDone: () => _removeClient(socket),
        cancelOnError: true,
      );
      socket.done.whenComplete(() => _removeClient(socket));
    });
  }

  /// 将重组后的 AnnexB 帧送入输出流。
///
  /// 转发受首个关键帧控制：关键帧前帧会被丢弃，
  /// 流会从第一个携带 VPS/SPS/PPS 的帧精确开始。
  /// 这样解码器会从干净 IDR 启动，并与已验证的参考客户端行为一致。
///
  /// 这里故意不在后续帧前重新注入参数集：
  /// 在 GOP 中间重发 SPS/PPS 会刷新解码器参考图像缓冲，
  /// 产生 “error constructing the frame RPS” 并导致 NALU 不可解码。
  /// 原始 HEVC 流本身已经在每个 IDR 前携带 VPS/SPS/PPS。
  void feedFrame(Uint8List data) {
    if (!_started) {
      if (_detectParameterSet(data)) {
        // 闸门打开：丢弃关键帧前无用帧，从该关键帧干净启动。
        _started = true;
        _pending.clear();
        _keyframe = data;
        _writeToClients(data);
      } else {
        // 仅用于诊断等待期间见到的帧数；这些帧不会输出。
        _pending.add(data);
        if (_pending.length > _maxPendingFrames) {
          _pending.removeAt(0);
        }
      }
      return;
    }
    // 更新缓存关键帧，确保后续接入的客户端拿到最近的参数集。
    if (_detectParameterSet(data)) {
      _keyframe = data;
    }
    _writeToClients(data);
  }

  /// 将缓存关键帧发送给刚连接的 [socket]，
  /// 让后接入的解码器一开始就获得参数集和 IDR。
  /// 闸门打开前为空操作。
///
  /// 该写入会计入转发统计；如果写入失败，说明客户端已断开并会被移除。
  void _replayKeyframe(Socket socket) {
    final keyframe = _keyframe;
    if (keyframe == null) return;
    try {
      socket.add(keyframe);
      framesForwarded++;
      bytesForwarded += keyframe.length;
    } on Exception catch (_) {
      _removeClient(socket);
    }
  }

  /// 向所有已连接客户端写入一帧并更新计数器。
///
  /// 只调用 [Socket.add]，不调用 flush()。flush() 返回 Future；
  /// 若 Future 尚未完成，IOSink 会处于绑定状态，
  /// 高频 add() 可能抛出 `Bad state: StreamSink is bound to a stream`。
  /// 这是 StateError，不会被下方 Exception 捕获，最终会中断数据流并丢帧。
  /// add() 已经把数据交给 OS；回环场景下几乎会立即送达。
  void _writeToClients(Uint8List data) {
    if (_clients.isEmpty) return;
    framesForwarded++;
    bytesForwarded += data.length;
    for (final client in List<Socket>.from(_clients)) {
      try {
        client.add(data);
      } on Exception catch (_) {
        // 客户端在写入途中断开，立即清理。
        _removeClient(client);
      }
    }
  }

  /// 幂等移除客户端套接字。
  void _removeClient(Socket socket) {
    _clients.remove(socket);
    try {
      socket.destroy();
    } on Exception catch (_) {}
  }

  /// 停止服务器并断开所有客户端。
  void stop() {
    for (final client in List<Socket>.from(_clients)) {
      client.destroy();
    }
    _clients.clear();
    _pending.clear();
    _started = false;
    _keyframe = null;
    _server?.close();
    _server = null;
  }

  /// 释放所有资源；等同于对此服务器调用 [stop]。
  void dispose() => stop();
}
