/// Unit tests for [CustomByteBlockSource].
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/core/protobuf/protobuf_parser.dart';
import 'package:robomaster_custom_client_1/features/custom_video/data/custom_byte_block_source.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:robomaster_custom_client_1/services/mqtt_service.dart';

/// Minimal in-memory [MqttService] for testing.
class _FakeMqttService implements MqttService {
  _FakeMqttService();

  final _controller = StreamController<({String topic, Uint8List payload})>.broadcast();
  final _subscribed = <String>{};

  @override
  MqttConnectionState get state => MqttConnectionState.connected;

  @override
  Stream<MqttConnectionState> get stateStream => Stream.value(MqttConnectionState.connected);

  @override
  Stream<({String topic, Uint8List payload})> get messageStream => _controller.stream;

  @override
  String clientId = 'test';

  @override
  void subscribe(String topic) {
    _subscribed.add(topic);
  }

  @override
  void unsubscribe(String topic) {
    _subscribed.remove(topic);
  }

  @override
  void publish(String topic, GeneratedMessage message) {}

  @override
  Future<void> connect({String? brokerIp, int? port}) => Future.value();

  @override
  void disconnect() {}

  @override
  void dispose() {
    _controller.close();
  }

  void emit(String topic, Uint8List payload) {
    _controller.add((topic: topic, payload: payload));
  }
}

void main() {
  group('CustomByteBlockSource', () {
    test('emits H.264 chunks from CustomByteBlock messages', () async {
      final mqtt = _FakeMqttService();
      final source = CustomByteBlockSource(
        mqttService: mqtt,
        parser: ProtobufParser(),
      );
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);

      source.start();
      expect(mqtt._subscribed, contains(topicCustomByteBlock));

      final block = CustomByteBlock(data: [0, 0, 0, 1, 0x67, 0x42, 0xC0, 0x1E]);
      mqtt.emit(topicCustomByteBlock, block.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(chunks.length, 1);
      expect(chunks.first, [0, 0, 0, 1, 0x67, 0x42, 0xC0, 0x1E]);

      await sub.cancel();
      source.dispose();
    });

    test('ignores messages on other topics', () async {
      final mqtt = _FakeMqttService();
      final source = CustomByteBlockSource(
        mqttService: mqtt,
        parser: ProtobufParser(),
      );
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);

      source.start();
      final block = CustomByteBlock(data: [0xAB, 0xCD]);
      mqtt.emit('SomeOtherTopic', block.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(chunks, isEmpty);

      await sub.cancel();
      source.dispose();
    });

    test('ignores empty data payloads', () async {
      final mqtt = _FakeMqttService();
      final source = CustomByteBlockSource(
        mqttService: mqtt,
        parser: ProtobufParser(),
      );
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);

      source.start();
      final block = CustomByteBlock(data: []);
      mqtt.emit(topicCustomByteBlock, block.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(chunks, isEmpty);

      await sub.cancel();
      source.dispose();
    });

    test('ignores payloads larger than 300 bytes', () async {
      final mqtt = _FakeMqttService();
      final source = CustomByteBlockSource(
        mqttService: mqtt,
        parser: ProtobufParser(),
      );
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);

      source.start();
      final block = CustomByteBlock(data: Uint8List(301));
      mqtt.emit(topicCustomByteBlock, block.writeToBuffer());

      await Future<void>.delayed(Duration.zero);
      expect(chunks, isEmpty);

      await sub.cancel();
      source.dispose();
    });

    test('unsubscribes on stop', () {
      final mqtt = _FakeMqttService();
      CustomByteBlockSource(
        mqttService: mqtt,
        parser: ProtobufParser(),
      )
        ..start()
        ..stop()
        ..dispose();
      expect(mqtt._subscribed, isNot(contains(topicCustomByteBlock)));
    });
  });
}
