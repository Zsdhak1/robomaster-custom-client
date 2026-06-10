/// HEVC video frame reassembler for UDP 3334 stream.
///
/// Parses UDP packet headers, caches fragments by [frameId],
/// and outputs complete AnnexB frames when all fragments arrive.
/// Incomplete frames are dropped after [frameReassemblyTimeout].
library;

import 'dart:async';
import 'dart:typed_data';

import '../constants/protocol_constants.dart';
import '../utils/byte_data_reader.dart';
import 'video_frame.dart';

/// Internal cache entry for a frame being reassembled.
class _FrameBuffer {
  _FrameBuffer({
    required this.frameId,
    required this.frameSize,
    required this.firstPacketTime,
  });

  final int frameId;
  final int frameSize;
  final DateTime firstPacketTime;

  /// Received fragments keyed by packet_id.
  ///
  /// Fragments are NOT assumed to be uniform size, so we store them by id
  /// and concatenate in packet_id order once the frame is complete. This
  /// matches the reference implementation and avoids the offset-arithmetic
  /// bug where a smaller final fragment corrupts the frame.
  final Map<int, Uint8List> packets = {};

  /// Number of bytes received so far (sum of all fragment lengths).
  int bytesReceived = 0;

  /// Whether this buffer has been completed.
  bool isComplete = false;

  /// Concatenates all fragments in packet_id order, trimmed to [frameSize].
  Uint8List assemble() {
    final sortedIds = packets.keys.toList()..sort();
    final out = Uint8List(frameSize);
    var pos = 0;
    for (final id in sortedIds) {
      final frag = packets[id]!;
      final remaining = frameSize - pos;
      if (remaining <= 0) break;
      final take = frag.length <= remaining ? frag.length : remaining;
      out.setRange(pos, pos + take, frag);
      pos += take;
    }
    return out;
  }
}

/// Reassembles HEVC frames from UDP packet fragments.
class FrameReassembler {
  /// Creates a [FrameReassembler].
  ///
  /// [maxFrames] limits concurrent cached frames to prevent memory leaks.
  /// [timeout] defines how long to wait for missing fragments.
  FrameReassembler({
    this.maxFrames = maxCachedFrames,
    this.timeout = frameReassemblyTimeout,
  });

  /// Maximum number of frames cached simultaneously.
  final int maxFrames;

  /// Timeout for incomplete frame reassembly.
  final Duration timeout;

  /// Frame ID -> buffer mapping.
  final Map<int, _FrameBuffer> _buffers = {};

  /// Completed frames output stream.
  final _frameController = StreamController<VideoFrame>.broadcast();

  /// Stream of fully reassembled frames.
  Stream<VideoFrame> get frameStream => _frameController.stream;

  /// Number of frames currently being reassembled.
  int get pendingFrameCount => _buffers.length;

  /// Total frames dropped due to timeout or overflow.
  int framesDropped = 0;

  /// Total frames successfully reassembled.
  int framesCompleted = 0;

  /// Frames completed that carried HEVC parameter sets (VPS/SPS/PPS).
  ///
  /// If this stays 0 while [framesCompleted] climbs, the keyframe carrying
  /// parameter sets is never fully reassembled — the root cause of a decoder
  /// that connects but renders nothing.
  int framesWithParamSet = 0;

  /// Largest fragment count seen in any single frame (complete or not).
  ///
  /// Keyframes span far more fragments than inter-frames; this reveals whether
  /// the big keyframe's fragments are even arriving.
  int maxFragmentsSeen = 0;

  /// Largest declared frame_size seen, in bytes.
  int maxFrameSizeSeen = 0;

  /// Periodic cleanup timer for stale buffers.
  Timer? _cleanupTimer;

  /// Starts background cleanup of stale frame buffers.
  void start() {
    _cleanupTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _cleanupStaleBuffers(),
    );
  }

  /// Stops background cleanup and releases resources.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _buffers.clear();
    _frameController.close();
  }

  /// Processes a single UDP packet.
  ///
  /// [packet] includes the 8-byte header + payload.
  /// Returns true if the packet was accepted.
  bool processPacket(Uint8List packet) {
    if (packet.length < udpPacketHeaderSize) {
      return false;
    }

    // Header fields are big-endian (network byte order). Reading them
    // little-endian inflates frame_size past the 4 MB cap (dropping every
    // packet) and scrambles packet_id, corrupting fragment offsets.
    final frameId = readUint16BE(packet, udpFrameIdOffset);
    final packetId = readUint16BE(packet, udpPacketIdOffset);
    final frameSize = readUint32BE(packet, udpFrameSizeOffset);

    if (frameSize > maxFrameSizeBytes || frameSize <= 0) {
      return false;
    }

    // COPY the payload (not sublistView): a view shares the datagram's
    // backing buffer, which the socket layer may reuse for the next packet —
    // corrupting an already-stored fragment and producing glitched frames /
    // "Could not find ref with POC". sublist() returns an independent copy.
    final payload = packet.sublist(udpPacketHeaderSize);

    _acceptFragment(frameId, packetId, frameSize, payload);
    return true;
  }

  void _acceptFragment(
    int frameId,
    int packetId,
    int frameSize,
    Uint8List payload,
  ) {
    _cleanupStaleBuffers();

    // Drop oldest frame if at capacity and this is a new frame.
    if (!_buffers.containsKey(frameId) && _buffers.length >= maxFrames) {
      final oldestId = _buffers.keys.reduce((a, b) => a < b ? a : b);
      _dropFrame(oldestId, reason: 'capacity');
    }

    final buffer = _buffers.putIfAbsent(
      frameId,
      () => _FrameBuffer(
        frameId: frameId,
        frameSize: frameSize,
        firstPacketTime: DateTime.now(),
      ),
    );

    // Defensive: discard if frameSize mismatch.
    if (buffer.frameSize != frameSize) {
      _dropFrame(frameId, reason: 'size_mismatch');
      return;
    }

    // Store the fragment by packet_id. Fragments are concatenated in
    // packet_id order at finalize time — no offset arithmetic, so a smaller
    // final fragment can't corrupt the frame.
    if (!buffer.packets.containsKey(packetId)) {
      buffer.packets[packetId] = payload;
      buffer.bytesReceived += payload.length;
    }

    // Track diagnostics: biggest frame and most-fragmented frame seen.
    if (frameSize > maxFrameSizeSeen) maxFrameSizeSeen = frameSize;
    if (buffer.packets.length > maxFragmentsSeen) {
      maxFragmentsSeen = buffer.packets.length;
    }

    // Check if frame is complete.
    if (buffer.bytesReceived >= frameSize) {
      _finalizeFrame(frameId);
    }
  }

  void _finalizeFrame(int frameId) {
    final buffer = _buffers[frameId];
    if (buffer == null || buffer.isComplete) return;

    buffer.isComplete = true;
    framesCompleted++;

    final now = DateTime.now();
    final assembled = buffer.assemble();
    if (hevcHasParameterSet(assembled)) {
      framesWithParamSet++;
    }
    final frame = VideoFrame(
      frameId: frameId,
      packetCount: buffer.packets.length,
      annexbData: ensureAnnexbPrefix(assembled),
      timestamp: now,
      reassemblyTime: now.difference(buffer.firstPacketTime),
    );

    _buffers.remove(frameId);
    _frameController.add(frame);
  }

  void _cleanupStaleBuffers() {
    final now = DateTime.now();
    final staleIds = _buffers.entries
        .where((e) => now.difference(e.value.firstPacketTime) > timeout)
        .map((e) => e.key)
        .toList();

    for (final id in staleIds) {
      _dropFrame(id, reason: 'timeout');
    }
  }

  void _dropFrame(int frameId, {required String reason}) {
    final buffer = _buffers.remove(frameId);
    if (buffer != null) {
      framesDropped++;
    }
  }
}
