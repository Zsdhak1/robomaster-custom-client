/// [h264HasParameterSet] 的单元测试。
///
/// 关键点：HEVC 参数集帧不能误打开 H.264 闸门，反之亦然。
/// 这种隔离保证两条视频链路不会互相破坏关键帧检测。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/video/h264_annexb_gate.dart';

/// 构建 AnnexB NAL 单元：4 字节起始码 + 1 字节 H.264 头部 + [trailing] 载荷。
/// H.264 头部低 5 位编码 `nal_unit_type`。
Uint8List h264Nal(int nalType, {List<int> trailing = const [0x00]}) {
  // forbidden_zero_bit=0，nal_ref_idc=3 (0b11)，类型位于低 5 位。
  final firstByte = 0x60 | (nalType & 0x1F);
  return Uint8List.fromList([0, 0, 0, 1, firstByte, ...trailing]);
}

/// 构建带 HEVC 风格首字节的 AnnexB NAL 单元。
/// 6 位 `nal_unit_type` 位于 bit 1..6（`type << 1`）。
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
