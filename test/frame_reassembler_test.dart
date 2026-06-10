/// Unit tests for [FrameReassembler] fragment handling.
///
/// Focus: the exact edge cases that cause "Could not find ref with POC"
/// glitching — a final fragment smaller than the MTU, out-of-order arrival,
/// dropped fragments, and (critically) whether a stored fragment can be
/// corrupted if the source datagram buffer is reused.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/video/frame_reassembler.dart';
import 'package:robomaster_custom_client_1/core/video/video_frame.dart';

/// Builds a UDP packet: 8-byte big-endian header + payload.
Uint8List makePacket(
  int frameId,
  int packetId,
  int frameSize,
  List<int> payload,
) {
  final b = BytesBuilder()
    ..add([(frameId >> 8) & 0xff, frameId & 0xff])
    ..add([(packetId >> 8) & 0xff, packetId & 0xff])
    ..add([
      (frameSize >> 24) & 0xff,
      (frameSize >> 16) & 0xff,
      (frameSize >> 8) & 0xff,
      frameSize & 0xff,
    ])
    ..add(payload);
  return b.toBytes();
}

void main() {
  group('FrameReassembler fragment reassembly', () {
    test('reassembles a multi-packet frame whose last packet is short',
        () async {
      final r = FrameReassembler();
      final frames = <VideoFrame>[];
      final sub = r.frameStream.listen(frames.add);

      // frame_size = 12: packet0=4 (1024-equivalent full), packet1=8... use
      // small numbers: p0 payload=8 bytes, p1 payload=4 bytes (short tail).
      const frameSize = 12;
      final p0 = makePacket(1, 0, frameSize, [0, 0, 0, 1, 0x40, 0x01, 0x0A, 0x0B]);
      final p1 = makePacket(1, 1, frameSize, [0x0C, 0x0D, 0x0E, 0x0F]);
      r
        ..processPacket(p0)
        ..processPacket(p1);
      await Future<void>.delayed(Duration.zero);

      expect(frames.length, 1);
      expect(
        frames.first.annexbData,
        [0, 0, 0, 1, 0x40, 0x01, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F],
      );
      await sub.cancel();
      r.dispose();
    });

    test('reassembles correctly when fragments arrive OUT OF ORDER', () async {
      final r = FrameReassembler();
      final frames = <VideoFrame>[];
      final sub = r.frameStream.listen(frames.add);

      const frameSize = 12;
      final p0 = makePacket(2, 0, frameSize, [0, 0, 0, 1, 0xAA, 0xBB, 0xCC, 0xDD]);
      final p1 = makePacket(2, 1, frameSize, [0x11, 0x22, 0x33, 0x44]);
      // Short tail arrives FIRST.
      r
        ..processPacket(p1)
        ..processPacket(p0);
      await Future<void>.delayed(Duration.zero);

      expect(frames.length, 1);
      expect(
        frames.first.annexbData,
        [0, 0, 0, 1, 0xAA, 0xBB, 0xCC, 0xDD, 0x11, 0x22, 0x33, 0x44],
      );
      await sub.cancel();
      r.dispose();
    });

    test('does NOT emit a frame when a fragment is missing', () async {
      final r = FrameReassembler();
      final frames = <VideoFrame>[];
      final sub = r.frameStream.listen(frames.add);

      const frameSize = 12;
      final p0 = makePacket(3, 0, frameSize, [0, 0, 0, 1, 0xAA, 0xBB, 0xCC, 0xDD]);
      // packet 1 (the short tail) is lost.
      r.processPacket(p0);
      await Future<void>.delayed(Duration.zero);

      expect(frames, isEmpty);
      expect(r.pendingFrameCount, 1);
      await sub.cancel();
      r.dispose();
    });

    test('stored fragment survives reuse of the source datagram buffer',
        () async {
      // CRITICAL: simulates RawDatagramSocket reusing its receive buffer.
      // If processPacket stores a VIEW into the packet, overwriting the
      // packet bytes after the call would corrupt the reassembled frame.
      final r = FrameReassembler();
      final frames = <VideoFrame>[];
      final sub = r.frameStream.listen(frames.add);

      const frameSize = 12;
      final p0 = makePacket(4, 0, frameSize, [0, 0, 0, 1, 0x40, 0x01, 0x0A, 0x0B]);
      r.processPacket(p0);
      // Reuse/overwrite the source buffer (what a pooled socket buffer does).
      for (var i = 0; i < p0.length; i++) {
        p0[i] = 0xFF;
      }
      final p1 = makePacket(4, 1, frameSize, [0x0C, 0x0D, 0x0E, 0x0F]);
      r.processPacket(p1);
      await Future<void>.delayed(Duration.zero);

      expect(frames.length, 1);
      // The first fragment must NOT have been corrupted to 0xFF.
      expect(
        frames.first.annexbData,
        [0, 0, 0, 1, 0x40, 0x01, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F],
        reason: 'fragment was a view into a reused buffer and got corrupted',
      );
      await sub.cancel();
      r.dispose();
    });
  });
}
