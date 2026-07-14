/// [AnnexbTcpServer] 高频写入崩溃的回归测试。
///
/// 问题源于旧版 `_writeToClients` 调用了 `client..add(data)..flush()`。
/// flush() 会让 IOSink 在 Future 完成前处于绑定状态，下一次高频 add() 会抛出
/// `Bad state: StreamSink is bound to a stream`。这是 StateError，不会被
/// `on Exception` 捕获，最终中断数据流并丢帧，引发解码器 “Could not find ref with POC” 花屏。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/services/annexb_tcp_server.dart';

/// 构建 AnnexB NAL：4 字节起始码 + 2 字节 NAL 头部 + 主体。
Uint8List nal(int nalType, List<int> body) {
  return Uint8List.fromList([0, 0, 0, 1, (nalType << 1) & 0xFF, 0x01, ...body]);
}

void main() {
  test('high-rate feed to a connected client neither throws nor stalls',
      () async {
    final server = AnnexbTcpServer();
    await server.start();
    addTearDown(server.stop);

    final received = <int>[];
    final client =
        await Socket.connect(InternetAddress.loopbackIPv4, server.port!);
    final sub = client.listen(received.addAll);
    addTearDown(() async {
      await sub.cancel();
      client.destroy();
    });

    // 给服务器一点时间注册客户端。
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // 关键帧（VPS = NAL 类型 32）会打开闸门。
    server.feedFrame(nal(32, [1, 2, 3, 4]));

    // 高频 P 帧。旧版 `add()..flush()` 会在第 2 次迭代抛出
    // "StreamSink is bound to a stream"。
    for (var i = 0; i < 500; i++) {
      server.feedFrame(nal(1, List<int>.filled(20, i & 0xFF)));
    }

    // 等待异步套接字写入排空。
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(server.framesForwarded, greaterThan(400),
        reason: 'feed crashed partway through');
    expect(received, isNotEmpty, reason: 'client received no bytes');
  });

  test('a decoder connecting AFTER the gate opened is primed with the keyframe',
      () async {
    final server = AnnexbTcpServer();
    await server.start();
    addTearDown(server.stop);

    // 真实竞态：桥接由 MQTT/UDP 喂入并打开闸门时，可能尚无解码器连接；
    // 播放器会在拿到桥接 URL 后异步接入。若不缓存关键帧，它会被转发给空客户端列表并丢失。
    final keyframe = nal(32, [1, 2, 3, 4]); // VPS（类型 32）打开闸门。
    server
      ..feedFrame(keyframe)
      ..feedFrame(nal(1, [9, 9, 9])); // 关键帧后的实时 P 帧。

    // 现在让一个解码器较晚接入。
    final received = <int>[];
    final client =
        await Socket.connect(InternetAddress.loopbackIPv4, server.port!);
    final sub = client.listen(received.addAll);
    addTearDown(() async {
      await sub.cancel();
      client.destroy();
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));

    // 它必须先收到缓存关键帧，否则会在没有参数集和 IDR 的白屏状态等待到下一个关键帧。
    expect(received, isNotEmpty, reason: 'late client got no keyframe');
    expect(received.take(keyframe.length).toList(), keyframe,
        reason: 'late client was not primed with the cached keyframe bytes');
  });
}
