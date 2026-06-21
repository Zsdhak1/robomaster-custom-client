/// Tracks the leading uint64 little-endian sequence number on each
/// `CustomByteBlock` packet to measure packet loss.
///
/// The robot prepends an 8-byte uint64 LE counter that increments by 1 per
/// packet. By watching for gaps between consecutive sequence numbers we can
/// report how many packets the link dropped, independent of the H.264 payload.
library;

import 'dart:typed_data';

/// Outcome of observing one packet's sequence number.
enum SeqObservation {
  /// First packet seen since reset — baseline, not counted as loss.
  first,

  /// Sequence advanced by exactly 1 — no loss.
  inOrder,

  /// Sequence advanced by more than 1 — the gap was counted as lost packets.
  gap,

  /// Sequence went backwards or repeated (reorder / restart) — not loss.
  regressed,
}

/// Accumulates sequence-number statistics for packet-loss reporting.
class PacketSequenceTracker {
  /// The last sequence number observed, or null before the first packet.
  int? _lastSeq;

  /// The first sequence number observed since [reset] (loss-rate baseline).
  int? _firstSeq;

  /// Total packets observed since [reset].
  int packetsSeen = 0;

  /// Total packets inferred lost from sequence gaps since [reset].
  int packetsLost = 0;

  /// Count of out-of-order / backwards sequence numbers since [reset].
  int regressions = 0;

  /// The most recently observed sequence number (for display).
  int get lastSeq => _lastSeq ?? 0;

  /// Whether any packet has been observed yet.
  bool get hasData => _lastSeq != null;

  /// Expected packet count = (last - first + 1) over the observed span.
  int get expectedPackets {
    final f = _firstSeq;
    final l = _lastSeq;
    if (f == null || l == null || l < f) return packetsSeen;
    return l - f + 1;
  }

  /// Packet-loss rate in [0, 1]: lost / expected over the observed span.
  double get lossRate {
    final expected = expectedPackets;
    if (expected <= 0) return 0;
    return packetsLost / expected;
  }

  /// Resets all counters (call on stream start/stop).
  void reset() {
    _lastSeq = null;
    _firstSeq = null;
    packetsSeen = 0;
    packetsLost = 0;
    regressions = 0;
  }

  /// Reads the uint64 LE sequence number from the first 8 bytes of [data] and
  /// updates the loss counters. Returns how the packet related to the previous
  /// one. If [data] is shorter than 8 bytes the packet is ignored (returns
  /// [SeqObservation.first] without mutating state).
  SeqObservation observe(Uint8List data) {
    if (data.length < 8) return SeqObservation.first;
    final seq = _readUint64Le(data);
    packetsSeen++;

    final prev = _lastSeq;
    if (prev == null) {
      _firstSeq = seq;
      _lastSeq = seq;
      return SeqObservation.first;
    }

    if (seq == prev + 1) {
      _lastSeq = seq;
      return SeqObservation.inOrder;
    }

    if (seq <= prev) {
      // Reorder, duplicate, or a counter restart. Don't count as loss. If it
      // looks like a restart (large backwards jump) rebase the baseline;
      // otherwise keep the high-water mark so a later in-order packet is not
      // mistaken for a forward gap.
      regressions++;
      if (prev - seq > 1024) {
        _firstSeq = seq;
        _lastSeq = seq;
        packetsLost = 0;
      }
      return SeqObservation.regressed;
    }

    // Forward gap: seq > prev + 1 → (seq - prev - 1) packets were lost.
    packetsLost += seq - prev - 1;
    _lastSeq = seq;
    return SeqObservation.gap;
  }

  /// Reads a little-endian uint64 from the first 8 bytes of [data].
  ///
  /// Dart ints are 64-bit signed; a sequence that exceeds 2^63 would wrap
  /// negative, but at 50 Hz that takes billions of years, so it is moot here.
  static int _readUint64Le(Uint8List data) {
    final bd = ByteData.sublistView(data, 0, 8);
    return bd.getUint64(0, Endian.little);
  }
}
