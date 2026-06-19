/// Unit tests for [h264HasParameterSet].
///
/// Critical: an HEVC parameter-set frame must NOT trip the H.264 gate, and
/// vice versa. This isolation is what keeps the two video lines from
/// corrupting each other's keyframe detection.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/video/h264_annexb_gate.dart';

/// Builds an AnnexB NAL unit: 4-byte start code + a first byte whose low 5
/// bits encode the H.264 nal_unit_type, followed by [trailing] payload bytes.
Uint8List h264Nal(int nalType, {List<int> trailing = const [0x00]}) {
  // forbidden_zero_bit=0, nal_ref_idc=3 (0b11), type in low 5 bits.
  final firstByte = 0x60 | (nalType & 0x1F);
  return Uint8List.fromList([0, 0, 0, 1, firstByte, ...trailing]);
}

/// Builds an AnnexB NAL unit with an HEVC-style first byte: the 6-bit
/// nal_unit_type sits in bits 1..6 (`type << 1`).
Uint8List hevcNal(int nalType, {List<int> trailing = const [0x00]}) {
  final firstByte = (nalType & 0x3F) << 1;
  return Uint8List.fromList([0, 0, 0, 1, firstByte, ...trailing]);
}

void main() {
  group('h264HasParameterSet', () {
    test('detects an SPS (type 7)', () {
      expect(h264HasParameterSet(h264Nal(7)), isTrue);
    });

    test('detects a PPS (type 8)', () {
      expect(h264HasParameterSet(h264Nal(8)), isTrue);
    });

    test('detects SPS with a 3-byte short start code', () {
      final nal = Uint8List.fromList([0, 0, 1, 0x67, 0x42]);
      expect(h264HasParameterSet(nal), isTrue);
    });

    test('an IDR slice (type 5) alone is NOT a parameter set', () {
      expect(h264HasParameterSet(h264Nal(5)), isFalse);
    });

    test('a non-IDR slice (type 1) is NOT a parameter set', () {
      expect(h264HasParameterSet(h264Nal(1)), isFalse);
    });

    test('an AUD (type 9) is NOT a parameter set', () {
      expect(h264HasParameterSet(h264Nal(9)), isFalse);
    });

    test('finds SPS when it follows an AUD in the same buffer', () {
      final buf = Uint8List.fromList([
        ...h264Nal(9), // AUD
        ...h264Nal(7), // SPS
      ]);
      expect(h264HasParameterSet(buf), isTrue);
    });

    test('HEVC VPS (32) does NOT trip the H.264 gate', () {
      expect(h264HasParameterSet(hevcNal(32)), isFalse);
    });

    test('HEVC SPS (33) does NOT trip the H.264 gate', () {
      expect(h264HasParameterSet(hevcNal(33)), isFalse);
    });

    test('HEVC PPS (34) does NOT trip the H.264 gate', () {
      expect(h264HasParameterSet(hevcNal(34)), isFalse);
    });

    test('empty data returns false', () {
      expect(h264HasParameterSet(Uint8List(0)), isFalse);
    });

    test('data with no start code returns false', () {
      expect(h264HasParameterSet(Uint8List.fromList([0x67, 0x42, 0xC0])), isFalse);
    });
  });
}
