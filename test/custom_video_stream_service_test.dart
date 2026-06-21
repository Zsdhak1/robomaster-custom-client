/// Unit tests for [CustomVideoStreamService] keyframe gating.
///
/// Focus: the SPS/PPS gate must work even when the parameter set straddles a
/// 300-byte CustomByteBlock boundary — the reason gating lives in the service
/// (over accumulated bytes) rather than per chunk.
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

      // Non-IDR slice (nal type 1): not a parameter set.
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x61, 0xAA]));
      await _tick();
      expect(service.gateOpen, isFalse);

      // SPS (nal type 7) -> gate opens.
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

      // First chunk ends mid-start-code.
      controller.add(Uint8List.fromList([0xFF, 0x00, 0x00]));
      await _tick();
      expect(service.gateOpen, isFalse);

      // Second chunk completes "00 00 00 01 67" (SPS) across the boundary.
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

      // Before any data: no chunk timestamp, empty gate buffer.
      expect(service.millisSinceLastChunk, isNull);
      expect(service.gateBufferBytes, 0);
      expect(service.tsWrap, isFalse);

      // Pre-keyframe junk accumulates in the gate buffer and is counted.
      controller.add(Uint8List.fromList([0, 0, 0, 1, 0x61, 0xAA]));
      await _tick();
      expect(service.chunksReceived, 1);
      expect(service.bytesReceived, 6);
      expect(service.gateBufferBytes, 6);
      expect(service.millisSinceLastChunk, isNotNull);

      // SPS opens the gate and flushes the gate buffer.
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
