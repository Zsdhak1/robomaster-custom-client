/// 独立复现脚本，不属于应用运行路径。
///
/// 使用项目真实的 [AnnexbTcpServer] 提供已捕获的 HEVC AnnexB 流，并打印
/// tcp:// URL 与实时统计。可让任何基于 libavformat 的解码器
///（ffmpeg / ffplay / libmpv）连接该 URL，验证 TCP 桥接输出是否可解码。
///
/// 运行：dart run tool/bridge_repro.dart [path-to-hevc] [秒]
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

  // 以约 60fps 循环推送文件内容。后接入的解码器仍可解码，
  // 因为桥接会先注入已缓存的参数集帧。
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

/// 将原始 AnnexB elementary stream 拆分为帧。
///
/// 每帧包含一组连续 NAL 单元，直到并包括第一个 VCL NAL（类型 0..31）。
/// 前导 non-VCL NAL（VPS/SPS/PPS/SEI/AUD，类型 >=32）会附加到该帧。
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
