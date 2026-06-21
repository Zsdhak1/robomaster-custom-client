/// Custom video line (0x0310 / CustomByteBlock) H.264 stream bridge.
///
/// Concatenates the ordered `CustomByteBlock` chunks into a continuous H.264
/// Annex-B byte stream and serves it over an independent loopback TCP bridge
/// for media_kit / fvp to decode. Kept entirely separate from the official
/// UDP 3334 / HEVC line: its own [AnnexbTcpServer] instance, its own H.264
/// keyframe gate.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

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

  /// Wall-clock time the most recent chunk arrived, for staleness detection.
  DateTime? _lastChunkAt;

  /// Count of H.264 NAL units seen per nal_unit_type since [start].
  ///
  /// Keys are the 5-bit H.264 nal_unit_type (1=non-IDR, 5=IDR keyframe,
  /// 6=SEI, 7=SPS, 8=PPS, 9=AUD). This is computed over the post-slice byte
  /// stream, so it tells you whether keyframes (5/7/8) actually arrive — the
  /// fast way to separate "link never sends keyframes" from "keyframes arrive
  /// but get corrupted by bad packing".
  final Map<int, int> _nalCounts = {};

  /// Trailing bytes from the previous chunk, so a start code split across a
  /// chunk boundary is still detected by the NAL scanner.
  final List<int> _nalScanTail = [];

  /// Wall-clock time the most recent IDR/SPS/PPS keyframe NAL was seen.
  DateTime? _lastKeyframeAt;

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

  /// Whether the served stream is wrapped in MPEG-TS (diagnostics).
  bool get tsWrap => _tsWrap;

  /// Bytes currently held in the pre-keyframe gate buffer (0 once open).
  int get gateBufferBytes => _gateBuffer.length;

  /// NAL unit counts per nal_unit_type over the post-slice stream.
  Map<int, int> get nalCounts => Map.unmodifiable(_nalCounts);

  /// Total IDR keyframe (type 5) NAL units seen since [start].
  int get keyframesSeen => _nalCounts[5] ?? 0;

  /// Total SPS (type 7) parameter-set NAL units seen since [start].
  int get spsSeen => _nalCounts[7] ?? 0;

  /// Milliseconds since the last keyframe/parameter-set NAL, or null if none.
  int? get millisSinceLastKeyframe {
    final at = _lastKeyframeAt;
    if (at == null) return null;
    return DateTime.now().difference(at).inMilliseconds;
  }

  /// Frames buffered by the bridge while waiting for the first keyframe.
  int get pendingFrames => _bridge.pendingCount;

  /// Milliseconds since the last chunk arrived, or null if none yet.
  ///
  /// A climbing value while [isRunning] means the MQTT feed has stalled — a
  /// fast way to tell "decoder stuck" from "source stopped sending".
  int? get millisSinceLastChunk {
    final at = _lastChunkAt;
    if (at == null) return null;
    return DateTime.now().difference(at).inMilliseconds;
  }

  // ---------------------------------------------------------------
  // 20-second stream dump (for debugging decoding issues)
  // ---------------------------------------------------------------

  /// Whether a dump is currently in progress.
  bool _dumping = false;

  /// Accumulator for the raw H.264 byte stream during a dump.
  final List<int> _dumpBuffer = [];

  /// Completer resolved with the dump file path when 20 s elapses.
  Completer<String>? _dumpCompleter;

  /// Timer that finalises the dump after 20 seconds.
  Timer? _dumpTimer;

  /// Whether a dump is running.
  bool get isDumping => _dumping;

  /// Starts a 20-second dump of the raw H.264 stream.
  ///
  /// Every chunk received during this window is appended to an in-memory buffer.
  /// After 20 seconds the accumulated bytes are written to a `.h264` file in
  /// the app's documents directory and the returned future completes with the
  /// file path.
  ///
  /// Calling [startDump] while a dump is already running is a no-op (returns
  /// the existing future).  Call [stopDump] to cancel early.
  Future<String> startDump() {
    if (_dumping) {
      return _dumpCompleter!.future;
    }
    _dumping = true;
    _dumpBuffer.clear();
    _dumpCompleter = Completer<String>();
    _dumpTimer = Timer(const Duration(seconds: 20), _finaliseDump);
    return _dumpCompleter!.future;
  }

  /// Cancels an in-progress dump without writing any data.
  void stopDump() {
    if (!_dumping) return;
    _dumpTimer?.cancel();
    _dumpTimer = null;
    _dumpBuffer.clear();
    _dumping = false;
    _dumpCompleter?.completeError(StateError('dump cancelled'));
    _dumpCompleter = null;
  }

  /// Writes the accumulated dump buffer to a timestamped `.h264` file.
  Future<void> _finaliseDump() async {
    _dumpTimer = null;
    _dumping = false;

    final data = Uint8List.fromList(_dumpBuffer);
    _dumpBuffer.clear();
    final completer = _dumpCompleter!;
    _dumpCompleter = null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/custom_video_dump_$ts.h264');
      await file.writeAsBytes(data);
      completer.complete(file.path);
    } catch (e) {
      completer.completeError(e);
    }
  }

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
    _lastChunkAt = null;
    _nalCounts.clear();
    _nalScanTail.clear();
    _lastKeyframeAt = null;
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
    _lastChunkAt = null;
    _bridge.stop();

    // Cancel any in-progress dump without writing.
    _dumpTimer?.cancel();
    _dumpTimer = null;
    _dumpBuffer.clear();
    if (_dumping) {
      _dumping = false;
      _dumpCompleter?.completeError(StateError('service stopped'));
      _dumpCompleter = null;
    }
  }

  /// Releases all resources.
  void dispose() => stop();

  void _onChunk(Uint8List chunk) {
    _chunksReceived++;
    _bytesReceived += chunk.length;
    _lastChunkAt = DateTime.now();

    // Tally NAL unit types over the post-slice stream so the debug panel can
    // show whether keyframes (IDR/SPS/PPS) actually arrive.
    _scanNalUnits(chunk);

    // Capture into dump buffer (pre-gate, so we see the raw stream exactly as
    // received, including any data the gate hasn't opened on yet).
    if (_dumping) {
      _dumpBuffer.addAll(chunk);
    }

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

  /// Counts H.264 NAL unit types in [chunk], bridging across chunk boundaries.
  ///
  /// Walks AnnexB start codes (3- or 4-byte) and reads the 5-bit nal_unit_type
  /// from the following byte. A short tail from the previous chunk is prepended
  /// so a start code split across a boundary is still counted exactly once.
  void _scanNalUnits(Uint8List chunk) {
    // Prepend up to 3 carried bytes so a boundary-straddling start code counts.
    final buf = _nalScanTail.isEmpty
        ? chunk
        : Uint8List.fromList([..._nalScanTail, ...chunk]);
    final n = buf.length;
    var i = 0;
    while (i + 3 < n) {
      final isLong = buf[i] == 0 &&
          buf[i + 1] == 0 &&
          buf[i + 2] == 0 &&
          buf[i + 3] == 1;
      final isShort = buf[i] == 0 && buf[i + 1] == 0 && buf[i + 2] == 1;
      if (isLong || isShort) {
        final hdr = i + (isLong ? 4 : 3);
        if (hdr < n) {
          final nalType = buf[hdr] & 0x1F;
          _nalCounts[nalType] = (_nalCounts[nalType] ?? 0) + 1;
          // 5=IDR, 7=SPS, 8=PPS are the keyframe/parameter-set NALs.
          if (nalType == 5 || nalType == 7 || nalType == 8) {
            _lastKeyframeAt = DateTime.now();
          }
        }
        i = hdr;
      } else {
        i++;
      }
    }
    // Carry the last 3 bytes so a start code straddling the next boundary is
    // not missed (a 4-byte start code needs at most 3 carried bytes).
    _nalScanTail
      ..clear()
      ..addAll(buf.sublist(n >= 3 ? n - 3 : 0));
  }
}
