/// Reassembled HEVC video frame from UDP stream.
library;

import 'dart:typed_data';

/// Represents a complete HEVC AnnexB frame after reassembly.
class VideoFrame {
  /// Creates a [VideoFrame] with validated parameters.
  VideoFrame({
    required this.frameId,
    required this.packetCount,
    required this.annexbData,
    required this.timestamp,
    required this.reassemblyTime,
  });

  /// Frame ID (shared by all fragments of this frame).
  final int frameId;

  /// Total number of UDP fragments that composed this frame.
  final int packetCount;

  /// Complete HEVC data with AnnexB start code prefix.
  final Uint8List annexbData;

  /// Timestamp when reassembly completed.
  final DateTime timestamp;

  /// Time from first fragment to complete reassembly.
  final Duration reassemblyTime;
}
