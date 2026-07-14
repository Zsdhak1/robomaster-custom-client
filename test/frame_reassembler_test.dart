/// [FrameReassembler] 分片处理的单元测试。
///
/// 关注会引发 “Could not find ref with POC” 花屏的边界场景：
/// 最后一个分片小于 MTU、乱序到达、缺失分片，以及源 datagram 缓冲区复用时
/// 已存储分片是否会被污染。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/video/frame_reassembler.dart';
import 'package:robomaster_custom_client_1/core/video/video_frame.dart';

/// 构建 UDP 包：8 字节大端序头部 + 载荷。
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

      // frame_size = 12：packet0=4（等价完整分片），packet1=8。
      // 使用小数字：p0 载荷 8 字节，p1 载荷 4 字节（短尾部）。
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
      // 短尾部分片先到达。
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
      // 包 1（短尾部）缺失。
      r.processPacket(p0);
      await Future<void>.delayed(Duration.zero);

      expect(frames, isEmpty);
      expect(r.pendingFrameCount, 1);
      await sub.cancel();
      r.dispose();
    });

    test('stored fragment survives reuse of the source datagram buffer',
        () async {
      // 关键：模拟 RawDatagramSocket 复用接收缓冲区。
      // 如果 processPacket 保存的是包视图，调用后覆盖源包字节会破坏已重组帧。
      final r = FrameReassembler();
      final frames = <VideoFrame>[];
      final sub = r.frameStream.listen(frames.add);

      const frameSize = 12;
      final p0 = makePacket(4, 0, frameSize, [0, 0, 0, 1, 0x40, 0x01, 0x0A, 0x0B]);
      r.processPacket(p0);
      // 复用并覆盖源缓冲区，模拟池化套接字缓冲区的行为。
      for (var i = 0; i < p0.length; i++) {
        p0[i] = 0xFF;
      }
      final p1 = makePacket(4, 1, frameSize, [0x0C, 0x0D, 0x0E, 0x0F]);
      r.processPacket(p1);
      await Future<void>.delayed(Duration.zero);

      expect(frames.length, 1);
      // 第一个分片不能被污染为 0xFF。
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
