/// Standalone reproduction harness — NOT part of the app.
///
/// Serves a real captured HEVC AnnexB stream through the project's actual
/// [AnnexbTcpServer] and prints the tcp:// URL + live stats. Point any
/// libavformat-based decoder (ffmpeg / ffplay / libmpv) at the URL to verify
/// the bridge serves a decodable stream over TCP.
///
/// Run:  dart run tool/bridge_repro.dart [path-to-hevc] [seconds]
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:robomaster_custom_client_1/services/annexb_tcp_server.dart';

Future<void> main(List<String> args) async {
  final path = args.isNotEmpty
      ? args[0]
      : r'G:\Projects\ClaudeProjects\rmu_client\video_stream.hevc';
  final runSeconds = args.length > 1 ? int.parse(args[1]) : 20;

  final bytes = File(path).readAsBytesSync();
  stdout.writeln('Loaded ${bytes.length} bytes from $path');

  final frames = _splitFrames(bytes);
  stdout.writeln('Split into ${frames.length} frames');
  final withPs = frames.where(_containsParamSet).length;
  stdout.writeln('Frames containing VPS/SPS/PPS: $withPs');

  final server = AnnexbTcpServer();
  await server.start();
  stdout.writeln('BRIDGE_URL=${server.streamUrl}');

  // Feed continuously at ~60fps, looping the file. Late-connecting decoders
  // still decode because the bridge injects cached parameter sets per frame.
  var idx = 0;
  final feeder = Timer.periodic(const Duration(milliseconds: 16), (_) {
    server.feedFrame(frames[idx % frames.length]);
    idx++;
  });

  final stats = Timer.periodic(const Duration(seconds: 1), (_) {
    stdout.writeln(
      'STATS clients=${server.clientCount} '
      'forwarded=${server.framesForwarded} '
      'bytes=${server.bytesForwarded} started=${server.hasStarted}',
    );
  });

  await Future<void>.delayed(Duration(seconds: runSeconds));
  feeder.cancel();
  stats.cancel();
  server.stop();
  stdout.writeln('DONE');
  exit(0);
}

/// Splits a raw AnnexB elementary stream into frames: each frame is the run
/// of NAL units ending at (and including) the first VCL NAL (type 0..31).
/// Leading non-VCL NALs (VPS/SPS/PPS/SEI/AUD, type >=32) attach to the frame.
List<Uint8List> _splitFrames(Uint8List d) {
  final starts = <int>[];
  final n = d.length;
  var i = 0;
  while (i + 3 < n) {
    final isLong = d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 0 && d[i + 3] == 1;
    final isShort = d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 1;
    if (isLong || isShort) {
      starts.add(i);
      i += isLong ? 4 : 3;
    } else {
      i++;
    }
  }
  starts.add(n);

  final frames = <Uint8List>[];
  var frameStart = starts.isEmpty ? 0 : starts[0];
  for (var s = 0; s < starts.length - 1; s++) {
    final nalPos = starts[s];
    final scLen = (d[nalPos + 2] == 1) ? 3 : 4;
    final hdr = nalPos + scLen;
    if (hdr >= n) break;
    final nalType = (d[hdr] >> 1) & 0x3F;
    final isVcl = nalType <= 31;
    if (isVcl) {
      final end = starts[s + 1];
      frames.add(Uint8List.sublistView(d, frameStart, end));
      frameStart = end;
    }
  }
  return frames;
}

bool _containsParamSet(Uint8List d) {
  final n = d.length;
  var i = 0;
  while (i + 3 < n) {
    final isLong = d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 0 && d[i + 3] == 1;
    final isShort = d[i] == 0 && d[i + 1] == 0 && d[i + 2] == 1;
    if (isLong || isShort) {
      final hdr = i + (isLong ? 4 : 3);
      if (hdr < n) {
        final t = (d[hdr] >> 1) & 0x3F;
        if (t == 32 || t == 33 || t == 34) return true;
      }
      i = hdr;
    } else {
      i++;
    }
  }
  return false;
}
