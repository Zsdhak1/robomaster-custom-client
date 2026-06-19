/// Custom video line (0x0310 / CustomByteBlock) H.264 stream bridge.
///
/// Concatenates the ordered `CustomByteBlock` chunks into a continuous H.264
/// Annex-B byte stream and serves it over an independent loopback TCP bridge
/// for media_kit / fvp to decode. Kept entirely separate from the official
/// UDP 3334 / HEVC line: its own [AnnexbTcpServer] instance, its own H.264
/// keyframe gate.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/video/h264_annexb_gate.dart';
import '../../../core/video/mpegts_muxer.dart';
import '../../../services/annexb_tcp_server.dart';

/// Maximum bytes buffered while waiting for the first H.264 keyframe.
///
/// An SPS/PPS can straddle a 300-byte `CustomByteBlock` boundary, so the gate
/// is evaluated over accumulated bytes rather than per chunk. Capped to bound
/// memory if a keyframe never arrives (e.g. stream joined mid-GOP).
const int _maxGateBufferBytes = 64 * 1024;

/// Bridges ordered H.264 chunks from MQTT into a loopback TCP stream.
class CustomVideoStreamService {
  /// Creates a service with an H.264-gated [AnnexbTcpServer].
  ///
  /// [bridge] is injectable for testing; by default it builds a fresh bridge
  /// whose keyframe gate detects either an H.264 parameter set (raw mode) or an
  /// MPEG-TS PAT (TS mode), depending on [_tsWrap] at [start] time.
  CustomVideoStreamService({AnnexbTcpServer? bridge}) {
    _bridge = bridge ?? AnnexbTcpServer(parameterSetDetector: _detectGate);
  }

  late final AnnexbTcpServer _bridge;

  /// Whether the served stream is wrapped in MPEG-TS (set per [start]).
  bool _tsWrap = false;

  /// Active muxer when [_tsWrap] is on; null in raw mode.
  MpegTsMuxer? _muxer;

  /// Gate detector dispatched by mode: TS PAT vs H.264 parameter set.
  bool _detectGate(Uint8List data) =>
      _tsWrap ? tsHasPat(data) : h264HasParameterSet(data);


  /// Subscription feeding chunks from the source into the bridge.
  StreamSubscription<Uint8List>? _sub;

  /// Accumulated pre-keyframe bytes (scanned for SPS/PPS across boundaries).
  final List<int> _gateBuffer = [];

  /// Whether the keyframe gate has opened and we now forward directly.
  bool _gateOpen = false;

  /// Whether the bridge is running.
  bool _running = false;

  /// Total `CustomByteBlock` chunks received from the source (upstream count).
  ///
  /// This counts MQTT arrivals BEFORE the keyframe gate, so it distinguishes
  /// "no MQTT data at all" (stays 0) from "data arrives but gate/decoder is
  /// stuck" (climbs while [gateOpen] / [decoderClients] stay false/0).
  int _chunksReceived = 0;

  /// Total bytes received from the source (upstream, pre-gate).
  int _bytesReceived = 0;

  /// Whether the bridge is currently active.
  bool get isRunning => _running;

  /// Chunks received from MQTT since [start] (pre-gate upstream count).
  int get chunksReceived => _chunksReceived;

  /// Bytes received from MQTT since [start] (pre-gate upstream count).
  int get bytesReceived => _bytesReceived;

  /// URL a decoder should open to read the H.264 stream (null when stopped).
  String? get streamUrl => _bridge.streamUrl;

  /// Whether the H.264 keyframe gate has opened.
  bool get gateOpen => _gateOpen;

  /// Total frames forwarded to decoder clients.
  int get framesForwarded => _bridge.framesForwarded;

  /// Total bytes forwarded to decoder clients.
  int get bytesForwarded => _bridge.bytesForwarded;

  /// Number of connected decoder clients.
  int get decoderClients => _bridge.clientCount;

  /// Starts the TCP bridge and begins forwarding [chunks].
  ///
  /// When [tsWrap] is true the gated H.264 stream is muxed into MPEG-TS before
  /// being served, so media_kit (which lacks a raw-H.264 demuxer) can play it.
  Future<void> start(Stream<Uint8List> chunks, {bool tsWrap = false}) async {
    if (_running) return;
    _tsWrap = tsWrap;
    _muxer = tsWrap ? MpegTsMuxer() : null;
    await _bridge.start();
    _gateOpen = false;
    _gateBuffer.clear();
    _chunksReceived = 0;
    _bytesReceived = 0;
    _sub = chunks.listen(_onChunk);
    _running = true;
  }

  /// Stops forwarding and releases the bridge.
  void stop() {
    _sub?.cancel();
    _sub = null;
    _gateBuffer.clear();
    _gateOpen = false;
    _running = false;
    _muxer = null;
    _bridge.stop();
  }

  /// Releases all resources.
  void dispose() => stop();

  void _onChunk(Uint8List chunk) {
    _chunksReceived++;
    _bytesReceived += chunk.length;
    if (_gateOpen) {
      _feed(chunk);
      return;
    }

    _gateBuffer.addAll(chunk);
    if (_gateBuffer.length > _maxGateBufferBytes) {
      _gateBuffer.removeRange(0, _gateBuffer.length - _maxGateBufferBytes);
    }

    final buffered = Uint8List.fromList(_gateBuffer);
    // Gate on the RAW H.264 parameter set (before muxing) so we start the bridge
    // exactly at the SPS/PPS the decoder needs, in either mode.
    if (h264HasParameterSet(buffered)) {
      _feed(buffered);
      _gateBuffer.clear();
      _gateOpen = true;
    }
  }

  /// Forwards [annexb] to the bridge, muxing to MPEG-TS first when enabled.
  void _feed(Uint8List annexb) {
    final muxer = _muxer;
    if (muxer == null) {
      _bridge.feedFrame(annexb);
      return;
    }
    final ts = muxer.addAnnexB(annexb);
    if (ts.isNotEmpty) _bridge.feedFrame(ts);
  }
}
