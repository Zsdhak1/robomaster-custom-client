/// Unit tests for the custom-video packet slicer.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/data/custom_packet_slicer.dart';

Uint8List u(List<int> b) => Uint8List.fromList(b);

void main() {
  group('stripVarintPrefix', () {
    test('strips 0x0A + 1-byte varint and drops padding', () {
      final r = stripVarintPrefix(u([0x0A, 0x04, 1, 2, 3, 4, 0, 0]));
      expect(r.prefixDetected, isTrue);
      expect(r.prefixBytes, 2);
      expect(r.declaredLength, 4);
      expect(r.bytes, [1, 2, 3, 4]);
    });

    test('decodes 2-byte varint length 150 (0x96 0x01)', () {
      final payload = List<int>.generate(150, (i) => i & 0xFF);
      final r = stripVarintPrefix(u([0x0A, 0x96, 0x01, ...payload]));
      expect(r.declaredLength, 150);
      expect(r.prefixBytes, 3);
      expect(r.bytes.length, 150);
    });

    test('decodes 2-byte varint length 297 (0xA9 0x02)', () {
      final payload = List<int>.generate(297, (i) => i & 0xFF);
      final r = stripVarintPrefix(u([0x0A, 0xA9, 0x02, ...payload]));
      expect(r.declaredLength, 297);
      expect(r.bytes.length, 297);
    });

    test('clamps to available bytes when declared length is too large', () {
      final r = stripVarintPrefix(u([0x0A, 0x0A, 1, 2, 3]));
      expect(r.declaredLength, 10);
      expect(r.bytes, [1, 2, 3]); // only 3 present
    });

    test('falls back to verbatim when no 0x0A prefix', () {
      final r = stripVarintPrefix(u([0x00, 0x00, 0x01, 0x67]));
      expect(r.prefixDetected, isFalse);
      expect(r.declaredLength, -1);
      expect(r.bytes, [0x00, 0x00, 0x01, 0x67]);
    });
  });

  group('sliceFixed', () {
    test('skips header and takes payload', () {
      final r = sliceFixed(u([9, 9, 1, 2, 3, 0, 0]), 2, 3);
      expect(r.bytes, [1, 2, 3]);
    });

    test('clamps to available when packet is short', () {
      final r = sliceFixed(u([9, 1, 2]), 1, 10);
      expect(r.bytes, [1, 2]);
    });
  });
}
