/// Regression test for the AnnexbTcpServer high-rate write crash.
///
/// The bug: `_writeToClients` did `client..add(data)..flush()`. flush() marks
/// the IOSink as bound until its Future completes; the next high-rate add()
/// then throws `Bad state: StreamSink is bound to a stream` (a StateError that
/// escapes the `on Exception` catch), crashing the feed and dropping frames →
/// decoder "Could not find ref with POC" glitches.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/services/annexb_tcp_server.dart';

/// Builds an AnnexB NAL: 4-byte start code + 2-byte NAL header + body.
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

    // Give the server a moment to register the client.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Keyframe (VPS = NAL type 32) opens the gate.
    server.feedFrame(nal(32, [1, 2, 3, 4]));

    // High-rate P-frames. With the old `add()..flush()` this threw
    // "StreamSink is bound to a stream" on the 2nd iteration.
    for (var i = 0; i < 500; i++) {
      server.feedFrame(nal(1, List<int>.filled(20, i & 0xFF)));
    }

    // Let the async socket writes drain.
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

    // The real-world race: the bridge is fed (by MQTT/UDP) and opens its gate
    // BEFORE any decoder attaches, because players connect asynchronously once
    // the bridge URL is known. The keyframe is forwarded to an empty client
    // list and would otherwise be lost.
    final keyframe = nal(32, [1, 2, 3, 4]); // VPS (type 32) opens the gate
    server
      ..feedFrame(keyframe)
      ..feedFrame(nal(1, [9, 9, 9])); // a live P-frame after the keyframe

    // Now a decoder connects late.
    final received = <int>[];
    final client =
        await Socket.connect(InternetAddress.loopbackIPv4, server.port!);
    final sub = client.listen(received.addAll);
    addTearDown(() async {
      await sub.cancel();
      client.destroy();
    });

    await Future<void>.delayed(const Duration(milliseconds: 100));

    // It must be primed with the cached keyframe, otherwise it would sit on a
    // white screen (no parameter sets / no IDR) until the next keyframe.
    expect(received, isNotEmpty, reason: 'late client got no keyframe');
    expect(received.take(keyframe.length).toList(), keyframe,
        reason: 'late client was not primed with the cached keyframe bytes');
  });
}
