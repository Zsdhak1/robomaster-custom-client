/// [CustomVideoStreamService] 关键帧闸门的单元测试。
///
/// 关注 SPS/PPS 闸门在参数集跨越 300 字节 CustomByteBlock 边界时仍能工作。
/// 因此门控位于服务层并基于累计字节，而不是逐块判断。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_stream_service.dart';

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  group('CustomVideoStreamService gating', () {
    test('stays closed on pre-keyframe junk, opens on SPS', () async {
      final service = CustomVideoStreamService();
      final controller = StreamController<Uint8List>();
      await service.start(controller.stream);

      // 非 IDR 切片（NAL 类型 1）：不是参数集。
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x61, 0xAA]));
      await _tick();
      expect(service.gateOpen, isFalse);

      // SPS（NAL 类型 7）会打开闸门。
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x67, 0x42, 0xC0]));
      await _tick();
      expect(service.gateOpen, isTrue);

      await controller.close();
      service.dispose();
    });

    test('detects an SPS split across two chunks', () async {
      final service = CustomVideoStreamService();
      final controller = StreamController<Uint8List>();
      await service.start(controller.stream);

      // 第一个块在起始码中间结束。
      controller.add(Uint8List.fromList([0xFF, 0x00, 0x00]));
      await _tick();
      expect(service.gateOpen, isFalse);

      // 第二个块跨边界补齐 "00 00 00 01 67"（SPS）。
      controller.add(Uint8List.fromList([0x00, 0x01, 0x67, 0x42]));
      await _tick();
      expect(service.gateOpen, isTrue);

      await controller.close();
      service.dispose();
    });

    test('stop resets gate state', () async {
      final service = CustomVideoStreamService();
      final controller = StreamController<Uint8List>.broadcast();
      await service.start(controller.stream);
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x67, 0x42]));
      await _tick();
      expect(service.gateOpen, isTrue);

      service.stop();
      expect(service.isRunning, isFalse);
      expect(service.gateOpen, isFalse);

      await controller.close();
      service.dispose();
    });

    test('exposes diagnostic counters used by the debug panel', () async {
      final service = CustomVideoStreamService();
      final controller = StreamController<Uint8List>();
      await service.start(controller.stream);

      // 尚未收到任何数据：无块时间戳，闸门缓冲区为空。
      expect(service.millisSinceLastChunk, isNull);
      expect(service.gateBufferBytes, 0);
      expect(service.tsWrap, isFalse);

      // 关键帧前的杂散字节会累计在闸门缓冲区中并计数。
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x61, 0xAA]));
      await _tick();
      expect(service.chunksReceived, 1);
      expect(service.bytesReceived, 6);
      expect(service.gateBufferBytes, 6);
      expect(service.millisSinceLastChunk, isNotNull);

      // SPS 打开闸门并刷新闸门缓冲区。
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x67, 0x42, 0xC0]));
      await _tick();
      expect(service.gateOpen, isTrue);
      expect(service.gateBufferBytes, 0);

      await controller.close();
      service.dispose();
    });

    test('tsWrap reflects the start parameter', () async {
      final service = CustomVideoStreamService();
      final controller = StreamController<Uint8List>();
      await service.start(controller.stream, tsWrap: true);
      expect(service.tsWrap, isTrue);

      await controller.close();
      service.dispose();
    });
  });
}
