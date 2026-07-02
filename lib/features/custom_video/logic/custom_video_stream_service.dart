/// Custom video line (0x0310 / CustomByteBlock) H.264/H.265 stream bridge.
///
/// Concatenates the ordered `CustomByteBlock` chunks into a continuous Annex‑B
/// byte stream (H.264 or H.265, selected per [start]) and serves it over an
/// independent loopback TCP bridge for media_kit / fvp to decode.  Kept
/// entirely separate from the official UDP 3334 / HEVC line: its own
/// [AnnexbTcpServer] instance, its own codec‑appropriate keyframe gate.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../core/video/h264_annexb_gate.dart';
import '../../../core/video/mpegts_muxer.dart';
import '../../../services/annexb_tcp_server.dart';
import '../../settings/logic/settings_providers.dart';

/// Maximum bytes buffered while waiting for the first keyframe.
///
/// An SPS/PPS can straddle a 300-byte `CustomByteBlock` boundary, so the gate
/// is evaluated over accumulated bytes rather than per chunk. Capped to bound
/// memory if a keyframe never arrives (e.g. stream joined mid-GOP).
const int _maxGateBufferBytes = 64 * 1024;

/// Bridges ordered H.264 or H.265 chunks from MQTT into a loopback TCP stream.
class CustomVideoStreamService {
  /// Creates a service with a codec‑agnostic [AnnexbTcpServer].
  ///
  /// [bridge] is injectable for testing; by default it builds a fresh bridge
  /// whose keyframe gate is updated to the active codec at [start] time.
  CustomVideoStreamService({AnnexbTcpServer? bridge}) {
    _bridge = bridge ?? AnnexbTcpServer(parameterSetDetector: _detectGate);
  }

  late AnnexbTcpServer _bridge;

  /// The active codec (set per [start]).
  CustomVideoCodec _codec = CustomVideoCodec.h264;

  /// Whether the served stream is wrapped in MPEG-TS (set per [start]).
  bool _tsWrap = false;

  /// Active muxer when [_tsWrap] is on; null in raw mode.
  MpegTsMuxer? _muxer;

  /// Gate detector dispatched by codec: H.264 → [h264HasParameterSet],
  /// H.265 → [h265HasParameterSet]; TS mode always uses [tsHasPat].
  bool _detectGate(Uint8List data) =>
      _tsWrap ? tsHasPat(data) : _codec == CustomVideoCodec.h265
          ? h265HasParameterSet(data)
          : h264HasParameterSet(data);

  /// Subscription feeding chunks from the source into the bridge.
  StreamSubscription<Uint8List>? _sub;

  /// Accumulated pre-keyframe bytes (scanned for parameter sets across boundaries).
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

  /// Count of NAL units seen per nal_unit_type since [start].
  ///
  /// Keys are the codec‑specific nal_unit_type — for H.264 the 5‑bit type
  /// (1=non‑IDR, 5=IDR, 7=SPS, 8=PPS), for HEVC the 6‑bit type
  /// (1=TRAIL_R, 19=IDR_W_RADL, 20=IDR_N_LP, 32=VPS, 33=SPS, 34=PPS).
  /// This is computed over the post‑slice byte stream, so it tells you whether
  /// keyframes actually arrive — the fast way to separate “link never sends
  /// keyframes” from “keyframes arrive but get corrupted by bad packing”.
  final Map<int, int> _nalCounts = {};

  /// Trailing bytes from the previous chunk, so a start code split across a
  /// chunk boundary is still detected by the NAL scanner.
  final List<int> _nalScanTail = [];

  /// Wall-clock time the most recent keyframe/parameter‑set NAL was seen.
  DateTime? _lastKeyframeAt;

  /// Whether the bridge is currently active.
  bool get isRunning => _running;

  /// The active codec for this session.
  CustomVideoCodec get codec => _codec;

  /// Chunks received from MQTT since [start] (pre-gate upstream count).
  int get chunksReceived => _chunksReceived;

  /// Bytes received from MQTT since [start] (pre-gate upstream count).
  int get bytesReceived => _bytesReceived;

  /// URL a decoder should open to read the video stream (null when stopped).
  String? get streamUrl => _bridge.streamUrl;

  /// Whether the keyframe gate has opened.
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

  // ---- H.264 NAL type helpers ----

  /// H.264 IDR keyframe NAL type.
  static const int _h264NalIdr = 5;

  /// H.264 SPS parameter set NAL type.
  static const int _h264NalSps = 7;

  /// H.264 non‑IDR slice NAL type.
  static const int _h264NalNonIdr = 1;

  // ---- H.265 (HEVC) NAL type helpers ----

  /// HEVC IDR_W_RADL keyframe NAL type.
  static const int _hevcNalIdrWRadl = 19;

  /// HEVC IDR_N_LP keyframe NAL type.
  static const int _hevcNalIdrNLp = 20;

  /// HEVC SPS parameter set NAL type.
  static const int _hevcNalSps = 33;

  /// HEVC VPS parameter set NAL type.
  static const int _hevcNalVps = 32;

  /// HEVC TRAIL_R (non‑IDR) NAL type.
  static const int _hevcNalTrailR = 1;

  /// Total IDR keyframe NAL units seen since [start] (codec‑aware).
  int get keyframesSeen {
    if (_codec == CustomVideoCodec.h265) {
      return (_nalCounts[_hevcNalIdrWRadl] ?? 0) +
          (_nalCounts[_hevcNalIdrNLp] ?? 0);
    }
    return _nalCounts[_h264NalIdr] ?? 0;
  }

  /// Total SPS parameter-set NAL units seen since [start] (codec‑aware).
  int get spsSeen {
    if (_codec == CustomVideoCodec.h265) {
      return _nalCounts[_hevcNalSps] ?? 0;
    }
    return _nalCounts[_h264NalSps] ?? 0;
  }

  /// Total VPS NAL units seen since [start] (HEVC only; always 0 for H.264).
  int get vpsSeen => _nalCounts[_hevcNalVps] ?? 0;

  /// Total non‑IDR slice NAL units seen since [start] (codec‑aware).
  int get nonIdrSeen {
    if (_codec == CustomVideoCodec.h265) {
      return _nalCounts[_hevcNalTrailR] ?? 0;
    }
    return _nalCounts[_h264NalNonIdr] ?? 0;
  }

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
  // 20-second stream dump
  // ---------------------------------------------------------------

  /// Whether a dump is currently in progress.
  bool _dumping = false;

  /// Accumulator for the raw byte stream during a dump.
  final List<int> _dumpBuffer = [];

  /// Completer resolved with the dump file path when 20 s elapses.
  Completer<String>? _dumpCompleter;

  /// Timer that finalises the dump after 20 seconds.
  Timer? _dumpTimer;

  /// Whether a dump is running.
  bool get isDumping => _dumping;

  /// Starts a 20-second dump of the raw byte stream.
  ///
  /// Every chunk received during this window is appended to an in-memory buffer.
  /// After 20 seconds the accumulated bytes are written to a `.h264` or `.hevc`
  /// file in the app's documents directory and the returned future completes
  /// with the file path.
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

  /// Writes the accumulated dump buffer to a timestamped file.
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
      final ext = _codec == CustomVideoCodec.h265 ? 'hevc' : 'h264';
      final file = File('${dir.path}/custom_video_dump_$ts.$ext');
      await file.writeAsBytes(data);
      completer.complete(file.path);
    } catch (e) {
      completer.completeError(e);
    }
  }

  /// Starts the TCP bridge and begins forwarding [chunks].
  ///
  /// When [tsWrap] is true the gated stream is muxed into MPEG-TS before being
  /// served, so media_kit (which lacks a raw-H.264 demuxer) can play it.
  /// [codec] selects the codec‑specific keyframe gate and NAL scanner.
  Future<void> start(
    Stream<Uint8List> chunks, {
    bool tsWrap = false,
    CustomVideoCodec codec = CustomVideoCodec.h264,
  }) async {
    if (_running) return;
    _codec = codec;
    _tsWrap = tsWrap;
    // Rebuild the bridge with the codec‑appropriate gate detector.
    _bridge.stop();
    _bridge = AnnexbTcpServer(parameterSetDetector: _detectGate);
    _muxer = tsWrap ? MpegTsMuxer(codec: codec) : null;
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
    // show whether keyframes actually arrive.
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
    // Gate on the RAW parameter set (before muxing) so we start the bridge
    // exactly at the SPS/PPS (or VPS/SPS/PPS for HEVC) the decoder needs.
    if (_codec == CustomVideoCodec.h265
        ? h265HasParameterSet(buffered)
        : h264HasParameterSet(buffered)) {
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

  /// Counts NAL unit types in [chunk], bridging across chunk boundaries.
  ///
  /// Walks AnnexB start codes (3- or 4-byte) and reads the codec‑specific
  /// nal_unit_type from the following byte (5‑bit for H.264, 6‑bit for HEVC).
  /// A short tail from the previous chunk is prepended so a start code split
  /// across a boundary is still counted exactly once.
  void _scanNalUnits(Uint8List chunk) {
    // Prepend up to 3 carried bytes so a boundary-straddling start code counts.
    final buf = _nalScanTail.isEmpty
        ? chunk
        : Uint8List.fromList([..._nalScanTail, ...chunk]);
    final n = buf.length;
    final isHevc = _codec == CustomVideoCodec.h265;
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
          // HEVC: 6‑bit nal_unit_type; H.264: 5‑bit nal_unit_type.
          final nalType = isHevc ? (buf[hdr] >> 1) & 0x3F : buf[hdr] & 0x1F;
          _nalCounts[nalType] = (_nalCounts[nalType] ?? 0) + 1;
          // Mark the most recent keyframe/parameter-set timestamp.
          if (_isKeyframeOrParam(nalType)) {
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

  /// Returns true when [nalType] is a keyframe or parameter-set NAL for the
  /// active codec.
  bool _isKeyframeOrParam(int nalType) {
    if (_codec == CustomVideoCodec.h265) {
      return nalType == _hevcNalIdrWRadl ||
          nalType == _hevcNalIdrNLp ||
          nalType == _hevcNalVps ||
          nalType == _hevcNalSps;
    }
    return nalType == _h264NalIdr ||
        nalType == _h264NalSps;
  }
}
