/// Unit tests for [PacketSequenceTracker].
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/data/packet_sequence_tracker.dart';

Uint8List seqPacket(int seq, [List<int> tail = const []]) {
  final b = BytesBuilder();
  final s = Uint8List(8);
  ByteData.sublistView(s).setUint64(0, seq, Endian.little);
  b
    ..add(s)
    ..add(tail);
  return b.toBytes();
}

void main() {
  group('PacketSequenceTracker', () {
    test('no loss for a contiguous run', () {
      final t = PacketSequenceTracker();
      for (var i = 0; i < 10; i++) {
        t.observe(seqPacket(i));
      }
      expect(t.lastSeq, 9);
      expect(t.packetsSeen, 10);
      expect(t.packetsLost, 0);
      expect(t.lossRate, 0);
    });

    test('counts a forward gap as lost packets', () {
      final t = PacketSequenceTracker()
        ..observe(seqPacket(0))
        ..observe(seqPacket(1))
        ..observe(seqPacket(5)); // lost 2,3,4
      expect(t.packetsLost, 3);
      expect(t.lastSeq, 5);
      // span = 6, lost 3 → 0.5
      expect(t.lossRate, closeTo(0.5, 1e-9));
    });

    test('ignores reorder/duplicate without inflating loss', () {
      final t = PacketSequenceTracker()
        ..observe(seqPacket(0))
        ..observe(seqPacket(1))
        ..observe(seqPacket(1)) // duplicate
        ..observe(seqPacket(0)) // reorder
        ..observe(seqPacket(2));
      expect(t.packetsLost, 0);
      expect(t.regressions, 2);
      expect(t.lastSeq, 2);
    });

    test('rebases after a large backwards jump (stream restart)', () {
      final t = PacketSequenceTracker()
        ..observe(seqPacket(10000))
        ..observe(seqPacket(10001))
        ..observe(seqPacket(0)) // restart
        ..observe(seqPacket(1));
      expect(t.packetsLost, 0);
      expect(t.lastSeq, 1);
    });

    test('ignores packets shorter than 8 bytes', () {
      final t = PacketSequenceTracker();
      final r = t.observe(Uint8List.fromList([1, 2, 3]));
      expect(r, SeqObservation.first);
      expect(t.packetsSeen, 0);
      expect(t.hasData, isFalse);
    });

    test('reset clears all counters', () {
      final t = PacketSequenceTracker()
        ..observe(seqPacket(0))
        ..observe(seqPacket(4))
        ..reset();
      expect(t.hasData, isFalse);
      expect(t.packetsSeen, 0);
      expect(t.packetsLost, 0);
    });
  });
}
