/// UDP 3334 HEVC video stream service.
///
/// Binds to UDP port, parses packet headers, delegates reassembly
/// to [FrameReassembler], and exposes the frame stream.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants/protocol_constants.dart';
import '../core/video/frame_reassembler.dart';
import '../core/video/video_frame.dart';
import 'annexb_tcp_server.dart';

/// Service for receiving and reassembling HEVC video frames over UDP.
class VideoStreamService {
  /// Creates a [VideoStreamService].
  ///
  /// [port] defaults to [defaultUdpVideoPort].
  VideoStreamService({int? port}) : _port = port ?? defaultUdpVideoPort;

  final int _port;

  /// Raw UDP socket for receiving packets.
  RawDatagramSocket? _socket;

  /// Frame reassembler instance.
  FrameReassembler? _reassembler;

  /// Subscription forwarding reassembled frames into [_frameController].
  StreamSubscription<VideoFrame>? _reassemblerSub;

  /// TCP bridge that serves the AnnexB stream to decoder players.
  final AnnexbTcpServer _tcpServer = AnnexbTcpServer();

  /// Subscription that feeds each frame into the TCP bridge.
  StreamSubscription<VideoFrame>? _tcpSub;

  /// Stable broadcast controller so [frameStream] survives start/stop cycles.
  final StreamController<VideoFrame> _frameController =
      StreamController<VideoFrame>.broadcast();

  /// Whether the service is currently listening.
  bool get isListening => _socket != null;

  /// Exposes the stream of reassembled video frames.
  ///
  /// Backed by a stable broadcast controller, so consumers may subscribe
  /// before [start] and keep receiving frames across start/stop cycles.
  Stream<VideoFrame> get frameStream => _frameController.stream;

  /// Frames successfully reassembled (0 when not listening).
  int get framesCompleted => _reassembler?.framesCompleted ?? 0;

  /// Frames dropped due to timeout/overflow (0 when not listening).
  int get framesDropped => _reassembler?.framesDropped ?? 0;

  /// Frames currently awaiting fragments (0 when not listening).
  int get pendingFrameCount => _reassembler?.pendingFrameCount ?? 0;

  /// URL for decoder players to consume the AnnexB stream.
  ///
  /// Null when the TCP bridge is not running.
  String? get streamUrl => _tcpServer.streamUrl;

  /// Total UDP packets received since start.
  int packetsReceived = 0;

  /// UDP packets dropped due to parse errors.
  int packetsDropped = 0;

  /// Whether the OS receive buffer (SO_RCVBUF) was successfully enlarged.
  ///
  /// 1080p60 HEVC sends bursty I-frames (~100+ packets at once); the default
  /// UDP buffer overflows and drops fragments, glitching the whole GOP.
  bool receiveBufferEnlarged = false;

  /// Number of currently connected decoder clients.
  int get decoderClients => _tcpServer.clientCount;

  /// Total frames forwarded into the TCP bridge.
  int get tcpFramesForwarded => _tcpServer.framesForwarded;

  /// Total bytes forwarded into the TCP bridge.
  int get tcpBytesForwarded => _tcpServer.bytesForwarded;

  /// Whether the keyframe gate has opened (VPS/SPS/PPS frame seen).
  bool get bridgeStarted => _tcpServer.hasStarted;

  /// Frames buffered in the bridge awaiting the first keyframe.
  int get bridgePending => _tcpServer.pendingCount;

  /// Completed frames that carried HEVC parameter sets (VPS/SPS/PPS).
  int get framesWithParamSet => _reassembler?.framesWithParamSet ?? 0;

  /// Largest fragment count seen in any single frame.
  int get maxFragmentsSeen => _reassembler?.maxFragmentsSeen ?? 0;

  /// Largest declared frame_size seen, in bytes.
  int get maxFrameSizeSeen => _reassembler?.maxFrameSizeSeen ?? 0;

  /// Raw bytes of the first received UDP packet (for header diagnosis).
  ///
  /// Null until at least one packet arrives. Captured once per [start].
  Uint8List? firstPacketBytes;

  /// Length in bytes of the first received UDP packet.
  int firstPacketLength = 0;

  /// frame_size parsed little-endian from the first packet (current logic).
  ///
  /// Returns null when no packet has been captured yet.
  int? get firstFrameSizeLittleEndian {
    final b = firstPacketBytes;
    if (b == null || b.length < 8) return null;
    return b[4] | (b[5] << 8) | (b[6] << 16) | (b[7] << 24);
  }

  /// frame_size parsed big-endian (network order) from the first packet.
  ///
  /// Returns null when no packet has been captured yet.
  int? get firstFrameSizeBigEndian {
    final b = firstPacketBytes;
    if (b == null || b.length < 8) return null;
    return (b[4] << 24) | (b[5] << 16) | (b[6] << 8) | b[7];
  }

  /// Starts listening on the UDP port and the TCP bridge.
  Future<void> start() async {
    if (_socket != null) return;

    packetsReceived = 0;
    packetsDropped = 0;

    // Start the TCP bridge so the decoder can connect before frames arrive.
    await _tcpServer.start();

    final reassembler = FrameReassembler()..start();
    _reassembler = reassembler;
    // Forward reassembled frames into the stable broadcast controller so
    // consumers subscribed before/after start keep receiving frames.
    _reassemblerSub = reassembler.frameStream.listen(_frameController.add);
    // Also feed frames into the TCP bridge for decoder rendering.
    _tcpSub = reassembler.frameStream.listen(
      (frame) => _tcpServer.feedFrame(frame.annexbData),
    );

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _port,
    );
    _enlargeReceiveBuffer(_socket!);

    _socket!.listen(_onPacket);
  }

  /// Enlarges the OS UDP receive buffer (SO_RCVBUF) to absorb bursty I-frame
  /// traffic. The default (~64–256 KB) overflows when a keyframe's ~100+
  /// packets arrive at once, dropping fragments — the lost keyframe then
  /// glitches the entire GOP ("Could not find ref with POC").
  ///
  /// SOL_SOCKET / SO_RCVBUF use raw platform constants; failure is non-fatal
  /// (a smaller buffer just means more drops under burst).
  void _enlargeReceiveBuffer(RawDatagramSocket socket) {
    const targetBytes = 8 * 1024 * 1024; // 8 MB
    // Android runs a Linux kernel, so it uses Linux's SOL_SOCKET/SO_RCVBUF
    // constants (1/8), NOT the BSD/Windows values (0xffff/0x1002). Platform
    // .isLinux is false on Android, hence the explicit isAndroid check.
    final linuxAbi = Platform.isLinux || Platform.isAndroid;
    final level = linuxAbi ? 1 : 0xffff; // SOL_SOCKET
    final option = linuxAbi ? 8 : 0x1002; // SO_RCVBUF
    try {
      // fromInt encodes the value as a 4-byte host-endian integer.
      socket.setRawOption(RawSocketOption.fromInt(level, option, targetBytes));
      receiveBufferEnlarged = true;
    } on Object catch (_) {
      receiveBufferEnlarged = false;
    }
  }

  /// Stops listening and releases the socket, reassembler and TCP bridge.
  ///
  /// The broadcast [frameStream] stays open so the UI can resubscribe on a
  /// later [start]; only [dispose] closes it permanently.
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

    // Drain EVERY queued datagram per read event. Under an I-frame burst many
    // datagrams can be ready at once; handling only one lets the socket buffer
    // back up and overflow, dropping fragments that glitch the GOP.
    for (Datagram? datagram = _socket!.receive();
        datagram != null;
        datagram = _socket!.receive()) {
      final data = datagram.data;
      packetsReceived++;

      // Capture the first packet's bytes for header diagnosis.
      if (firstPacketBytes == null) {
        firstPacketLength = data.length;
        final take = data.length < 16 ? data.length : 16;
        firstPacketBytes = Uint8List.fromList(data.sublist(0, take));
      }

      final accepted = _reassembler!.processPacket(data);
      if (!accepted) {
        packetsDropped++;
      }
    }
  }

  /// Releases all resources, including the broadcast [frameStream].
  void dispose() {
    stop();
    _frameController.close();
  }
}
