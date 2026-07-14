/// [CustomByteBlockSource] 的单元测试。
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/core/protobuf/protobuf_parser.dart';
import 'package:robomaster_custom_client_1/features/custom_video/data/custom_byte_block_source.dart';
import 'package:robomaster_custom_client_1/features/settings/logic/settings_providers.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:robomaster_custom_client_1/services/mqtt_service.dart';

/// 最小 in-memory [MqttService] 用于 testing。
class _FakeMqttService implements MqttService {
  _FakeMqttService();

  final _controller =
      StreamController<({String topic, Uint8List payload})>.broadcast();
  final _subscribed = <String>{};

  @override
  MqttConnectionState get state => MqttConnectionState.connected;

  @override
  Stream<MqttConnectionState> get stateStream =>
      Stream.value(MqttConnectionState.connected);

  @override
  Stream<({String topic, Uint8List payload})> get messageStream =>
      _controller.stream;

  @override
  String clientId = 'test';

  @override
  void subscribe(String topic) => _subscribed.add(topic);

  @override
  void unsubscribe(String topic) => _subscribed.remove(topic);

  @override
  void publish(String topic, GeneratedMessage message) {}

  @override
  Future<void> connect({String? brokerIp, int? port}) => Future.value();

  @override
  void disconnect() {}

  @override
  void dispose() => _controller.close();

  void emit(String topic, Uint8List payload) =>
      _controller.add((topic: topic, payload: payload));
}

void main() {
  group('CustomByteBlockSource', () {
    CustomByteBlockSource build(
      _FakeMqttService mqtt, {
      CustomVideoSliceMode mode = CustomVideoSliceMode.stripPrefix,
      int headerBytes = 3,
      int payloadBytes = 150,
      bool seqHeader = false,
    }) {
      return CustomByteBlockSource(
        mqttService: mqtt,
        parser: ProtobufParser(),
        sliceMode: () => mode,
        headerBytes: () => headerBytes,
        payloadBytes: () => payloadBytes,
        seqHeaderEnabled: () => seqHeader,
      );
    }

    test('stripPrefix removes 0x0A+varint prefix and trailing padding',
        () async {
      final mqtt = _FakeMqttService();
      final source = build(mqtt);
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();
      expect(mqtt._subscribed, contains(topicCustomByteBlock));

      // 数据 = 0x0A 0x04 <4 字节载荷> <填充>，声明长度为 4。
      mqtt.emit(
        topicCustomByteBlock,
        CustomByteBlock(data: [0x0A, 0x04, 0xAA, 0xBB, 0xCC, 0xDD, 0, 0])
            .writeToBuffer(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(chunks.length, 1);
      expect(chunks.first, [0xAA, 0xBB, 0xCC, 0xDD]);
      expect(source.packetsWithPrefix, 1);
      expect(source.lastDeclaredLength, 4);

      await sub.cancel();
      source.dispose();
    });

    test('stripPrefix decodes a 2-byte varint length (150)', () async {
      final mqtt = _FakeMqttService();
      final source = build(mqtt);
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();

      // 0x96 0x01 是 varint 150，提供精确 150 字节载荷。
      final payload = List<int>.generate(150, (i) => i & 0xFF);
      mqtt.emit(
        topicCustomByteBlock,
        CustomByteBlock(data: [0x0A, 0x96, 0x01, ...payload]).writeToBuffer(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(chunks.length, 1);
      expect(chunks.first.length, 150);
      expect(chunks.first, payload);
      expect(source.lastDeclaredLength, 150);

      await sub.cancel();
      source.dispose();
    });

    test('stripPrefix flags truncation when declared > available', () async {
      final mqtt = _FakeMqttService();
      final source = build(mqtt);
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();

      // 声明 10 字节但后续只有 3 字节 → 截断，发出实际存在的 3 字节。
      mqtt.emit(
        topicCustomByteBlock,
        CustomByteBlock(data: [0x0A, 0x0A, 0x11, 0x22, 0x33]).writeToBuffer(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(chunks.first, [0x11, 0x22, 0x33]);
      expect(source.packetsTruncated, 1);

      await sub.cancel();
      source.dispose();
    });

    test('verbatim forwards data unchanged (baseline)', () async {
      final mqtt = _FakeMqttService();
      final source = build(mqtt, mode: CustomVideoSliceMode.verbatim);
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();

      mqtt.emit(
        topicCustomByteBlock,
        CustomByteBlock(data: [0x0A, 0x04, 0xAA, 0xBB, 0xCC, 0xDD])
            .writeToBuffer(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(chunks.first, [0x0A, 0x04, 0xAA, 0xBB, 0xCC, 0xDD]);
      expect(source.packetsWithPrefix, 0);

      await sub.cancel();
      source.dispose();
    });

    test('fixed mode skips header and takes payload bytes', () async {
      final mqtt = _FakeMqttService();
      final source = build(
        mqtt,
        mode: CustomVideoSliceMode.fixed,
        headerBytes: 2,
        payloadBytes: 3,
      );
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();

      mqtt.emit(
        topicCustomByteBlock,
        CustomByteBlock(data: [0xAA, 0xBB, 0x11, 0x22, 0x33, 0, 0])
            .writeToBuffer(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(chunks.first, [0x11, 0x22, 0x33]);

      await sub.cancel();
      source.dispose();
    });

    test('ignores other topics and empty payloads', () async {
      final mqtt = _FakeMqttService();
      final source = build(mqtt);
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();

      mqtt
        ..emit('SomeOtherTopic',
            CustomByteBlock(data: [0x0A, 0x01, 0xAB]).writeToBuffer())
        ..emit(topicCustomByteBlock,
            CustomByteBlock(data: <int>[]).writeToBuffer());
      await Future<void>.delayed(Duration.zero);

      expect(chunks, isEmpty);

      await sub.cancel();
      source.dispose();
    });

    test('unsubscribes on stop', () {
      final mqtt = _FakeMqttService();
      build(mqtt)
        ..start()
        ..stop()
        ..dispose();
      expect(mqtt._subscribed, isNot(contains(topicCustomByteBlock)));
    });

    test('seq header: strips 8-byte seq and counts loss from gaps', () async {
      final mqtt = _FakeMqttService();
      // verbatim 切片会原样转发序列号之后的主体。
      final source = build(
        mqtt,
        mode: CustomVideoSliceMode.verbatim,
        seqHeader: true,
      );
      final chunks = <Uint8List>[];
      final sub = source.chunkStream.listen(chunks.add);
      source.start();

      Uint8List packet(int seq, List<int> body) {
        final b = BytesBuilder();
        final s = Uint8List(8);
        ByteData.sublistView(s).setUint64(0, seq, Endian.little);
        b
          ..add(s)
          ..add(body);
        return CustomByteBlock(data: b.toBytes()).writeToBuffer();
      }

      // seq 0,1,2 后跳到 5（丢失 3,4），随后到 6。
      mqtt
        ..emit(topicCustomByteBlock, packet(0, [0xA0]))
        ..emit(topicCustomByteBlock, packet(1, [0xA1]))
        ..emit(topicCustomByteBlock, packet(2, [0xA2]))
        ..emit(topicCustomByteBlock, packet(5, [0xA5]))
        ..emit(topicCustomByteBlock, packet(6, [0xA6]));
      await Future<void>.delayed(Duration.zero);

      // 8 字节 seq 之后的主体会被 verbatim 原样转发。
      expect(chunks.map((c) => c.first).toList(), [0xA0, 0xA1, 0xA2, 0xA5, 0xA6]);
      expect(source.lastSequence, 6);
      expect(source.seqPacketsSeen, 5);
      expect(source.packetsLost, 2); // 3 和 4
      // 范围 = 6 - 0 + 1 = 7，丢失 2 → ~0.2857
      expect(source.lossRate, closeTo(2 / 7, 1e-9));

      await sub.cancel();
      source.dispose();
    });
  });
}
