/// UDP 3334 HEVC 视频流服务。
///
/// 绑定 UDP 端口，读取包并交给 [FrameReassembler] 重组，
/// 再向上暴露完整帧流。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants/protocol_constants.dart';
import '../core/video/frame_reassembler.dart';
import '../core/video/video_frame.dart';
import 'annexb_tcp_server.dart';

/// 通过 UDP 接收并重组 HEVC 视频帧的服务。
class VideoStreamService {
  /// 创建 [VideoStreamService]。
  ///
  /// [port] 默认为 [defaultUdpVideoPort]。
  VideoStreamService({int? port}) : _port = port ?? defaultUdpVideoPort;

  final int _port;

  /// 接收 UDP 包的原始套接字。
  RawDatagramSocket? _socket;

  /// 帧重组器实例。
  FrameReassembler? _reassembler;

  /// 将重组后的帧转发到 [_frameController] 的订阅。
  StreamSubscription<VideoFrame>? _reassemblerSub;

  /// 将 AnnexB 流提供给解码器播放器的 TCP 桥接。
  final AnnexbTcpServer _tcpServer = AnnexbTcpServer();

  /// 将每帧送入 TCP 桥接的订阅。
  StreamSubscription<VideoFrame>? _tcpSub;

  /// 稳定的广播控制器，让 [frameStream] 可跨 start/stop 周期复用。
  final StreamController<VideoFrame> _frameController =
      StreamController<VideoFrame>.broadcast();

  /// 服务当前是否正在监听。
  bool get isListening => _socket != null;

  /// 对外暴露已重组的视频帧流。
///
  /// 底层使用稳定的广播控制器，因此调用方可以在 [start] 前订阅，
  /// 并在多次启动/停止之间持续接收帧。
  Stream<VideoFrame> get frameStream => _frameController.stream;

  /// 成功重组的帧数（未监听时为 0）。
  int get framesCompleted => _reassembler?.framesCompleted ?? 0;

  /// 因超时或溢出丢弃的帧数（未监听时为 0）。
  int get framesDropped => _reassembler?.framesDropped ?? 0;

  /// 当前等待分片补齐的帧数（未监听时为 0）。
  int get pendingFrameCount => _reassembler?.pendingFrameCount ?? 0;

  /// 解码器播放器读取 AnnexB 流的 URL。
///
  /// TCP 桥接未运行时为 null。
  String? get streamUrl => _tcpServer.streamUrl;

  /// 自启动以来接收的 UDP 包总数。
  int packetsReceived = 0;

  /// 因解析错误丢弃的 UDP 包数。
  int packetsDropped = 0;

  /// 是否成功放大 OS 接收缓冲区（SO_RCVBUF）。
///
  /// 1080p60 HEVC 的 I 帧会突发发送约 100+ 个包；
  /// 默认 UDP 缓冲区容易溢出并丢分片，导致整段 GOP 花屏。
  bool receiveBufferEnlarged = false;

  /// 当前已连接的解码器客户端数。
  int get decoderClients => _tcpServer.clientCount;

  /// 已转发进 TCP 桥接的总帧数。
  int get tcpFramesForwarded => _tcpServer.framesForwarded;

  /// 已转发进 TCP 桥接的总字节数。
  int get tcpBytesForwarded => _tcpServer.bytesForwarded;

  /// 关键帧闸门是否已打开（已见到 VPS/SPS/PPS 帧）。
  bool get bridgeStarted => _tcpServer.hasStarted;

  /// 桥接中等待首个关键帧的缓存帧数。
  int get bridgePending => _tcpServer.pendingCount;

  /// 已完成且携带 HEVC 参数集（VPS/SPS/PPS）的帧数。
  int get framesWithParamSet => _reassembler?.framesWithParamSet ?? 0;

  /// 单帧内已见到的最大分片数。
  int get maxFragmentsSeen => _reassembler?.maxFragmentsSeen ?? 0;

  /// 已见到的最大声明 frame_size，单位字节。
  int get maxFrameSizeSeen => _reassembler?.maxFrameSizeSeen ?? 0;

  /// 首个 UDP 包的原始字节（用于包头诊断）。
///
  /// 每次 [start] 后只捕获一次；首包到达前为 null。
  Uint8List? firstPacketBytes;

  /// 首个 UDP 包长度，单位字节。
  int firstPacketLength = 0;

  /// 从首包按小端序解析出的 frame_size（诊断当前错误假设）。
///
  /// 尚未捕获首包时返回 null。
  int? get firstFrameSizeLittleEndian {
    final b = firstPacketBytes;
    if (b == null || b.length < 8) return null;
    return b[4] | (b[5] << 8) | (b[6] << 16) | (b[7] << 24);
  }

  /// 从首包按大端序（网络字节序）解析出的 frame_size。
///
  /// 尚未捕获首包时返回 null。
  int? get firstFrameSizeBigEndian {
    final b = firstPacketBytes;
    if (b == null || b.length < 8) return null;
    return (b[4] << 24) | (b[5] << 16) | (b[6] << 8) | b[7];
  }

  /// 启动 UDP 端口监听和 TCP 桥接。
  Future<void> start() async {
    if (_socket != null) return;

    packetsReceived = 0;
    packetsDropped = 0;
    receiveBufferEnlarged = false;
    firstPacketBytes = null;
    firstPacketLength = 0;

    try {
      // 先启动 TCP 桥接，让解码器可在帧到达前连接。
      await _tcpServer.start();

      final reassembler = FrameReassembler()..start();
      _reassembler = reassembler;
      // 将重组后的帧转发到稳定广播控制器，
      // 让 start 前后订阅的调用方都能持续收到帧。
      _reassemblerSub = reassembler.frameStream.listen(_frameController.add);
      // 同时把帧送入 TCP 桥接，供解码器渲染。
      _tcpSub = reassembler.frameStream.listen(
        (frame) => _tcpServer.feedFrame(frame.annexbData),
      );

      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _port,
      );
      _enlargeReceiveBuffer(_socket!);

      _socket!.listen(_onPacket);
    } on Object {
      stop();
      rethrow;
    }
  }

  /// 放大 OS UDP 接收缓冲区（SO_RCVBUF），吸收 I 帧突发流量。
  /// 默认缓冲区约 64-256 KB，当关键帧的 100+ 个包同时到达时容易溢出；
  /// 一旦关键帧分片丢失，整段 GOP 都可能花屏并出现
  /// “Could not find ref with POC”。
///
  /// SOL_SOCKET / SO_RCVBUF 使用平台原始常量；设置失败不致命，
  /// 只是突发流量下更容易丢包。
  void _enlargeReceiveBuffer(RawDatagramSocket socket) {
    const targetBytes = 8 * 1024 * 1024; // 8 MB
    // Android 运行 Linux 内核，因此使用 Linux 的 SOL_SOCKET/SO_RCVBUF
    // 常量 (1/8)，不是 BSD/Windows 值 (0xffff/0x1002)。
    // Platform.isLinux 在 Android 上为 false，所以要显式判断 isAndroid。
    final linuxAbi = Platform.isLinux || Platform.isAndroid;
    final level = linuxAbi ? 1 : 0xffff; // SOL_SOCKET
    final option = linuxAbi ? 8 : 0x1002; // SO_RCVBUF
    try {
      // fromInt 会把值编码为 4 字节主机字节序整数。
      socket.setRawOption(RawSocketOption.fromInt(level, option, targetBytes));
      receiveBufferEnlarged = true;
    } on Object catch (_) {
      receiveBufferEnlarged = false;
    }
  }

  /// 停止监听并释放套接字、重组器和 TCP 桥接。
///
  /// 广播 [frameStream] 会保持打开，便于 UI 在之后的 [start] 中重新订阅；
  /// 只有 [dispose] 会永久关闭它。
  void stop() {
    _socket?.close();
    _socket = null;
    _reassemblerSub?.cancel();
    _reassemblerSub = null;
    _tcpSub?.cancel();
    _tcpSub = null;
    _reassembler?.dispose();
    _reassembler = null;
    _tcpServer.stop();
  }

  void _onPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;

    final socket = _socket;
    final reassembler = _reassembler;
    if (socket == null || reassembler == null) return;

    // 每次 read 事件都要清空所有已排队 datagram。
    // I 帧突发时可能一次准备好很多包；如果只处理一个，
    // 套接字缓冲区会积压并溢出，导致分片丢失和 GOP 花屏。
    for (Datagram? datagram = socket.receive();
        datagram != null;
        datagram = socket.receive()) {
      final data = datagram.data;
      packetsReceived++;

      // 捕获首包字节用于包头诊断。
      if (firstPacketBytes == null) {
        firstPacketLength = data.length;
        final take = data.length < 16 ? data.length : 16;
        firstPacketBytes = Uint8List.fromList(data.sublist(0, take));
      }

      final accepted = reassembler.processPacket(data);
      if (!accepted) {
        packetsDropped++;
      }
    }
  }

  /// 释放所有资源，包括广播 [frameStream]。
  void dispose() {
    stop();
    _frameController.close();
  }
}
