/// [MpegTsMuxer] 的结构性测试。
///
/// 端到端可解码性已通过 ffprobe/ffmpeg 单独校验：
/// 封装器对真实 .h264 dump 的输出可被识别为干净的 400x400 H.264 流。
/// 这些测试固定解码器依赖的线上字节格式约束。
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/video/mpegts_muxer.dart';

/// 构建 Annex-B NAL：4 字节起始码 + 1 字节 H.264 头部 + 主体。
Uint8List nal(int type, List<int> body) {
  return Uint8List.fromList([0, 0, 0, 1, type & 0x1F, ...body]);
}

/// 拼接字节列表。
Uint8List cat(List<Uint8List> parts) {
  final b = BytesBuilder();
  for (final p in parts) {
    b.add(p);
  }
  return b.toBytes();
}

/// 可推进的单调假时钟，单位为微秒，不使用 `DateTime.now`。
class FakeClock {
  int micros = 0;
  int call() => micros;
  void advanceMs(int ms) => micros += ms * 1000;
}

/// 已解析访问单元的 video-PID TS 包：包含包字节偏移，以及跳过 TS 头部和 adaptation
/// 字段后的载荷起始位置。
class _VidPacket {
  // ignore: avoid_positional_boolean_parameters
  _VidPacket(this.offset, this.payloadStart, this.hasAf, this.afFlags,
      this.afStart);
  final int offset;
  final int payloadStart;
  final bool hasAf;
  final int afFlags;
  final int afStart;
}

/// 查找第一个设置了 payload-unit-start 指示器的 video-PID (0x100) TS 包，
/// 并返回包、载荷和 adaptation-field 偏移。
_VidPacket? _firstVideoPacket(Uint8List ts) {
  for (var i = 0; i + 188 <= ts.length; i += 188) {
    if (ts[i] != 0x47) continue;
    final pusi = (ts[i + 1] & 0x40) != 0;
    final pid = ((ts[i + 1] & 0x1F) << 8) | ts[i + 2];
    final afc = (ts[i + 3] >> 4) & 0x03;
    if (pid != 0x100 || !pusi) continue;
    final hasAf = afc == 0x02 || afc == 0x03;
    final afLen = hasAf ? ts[i + 4] : 0;
    final afStart = i + 5; // 位于 AF 长度字节之后。
    final afFlags = (hasAf && afLen > 0) ? ts[afStart] : 0;
    // 载荷位于 4 字节 TS 头部和 AF（长度字节 + AF 内容）之后。
    final payloadStart = hasAf ? i + 5 + afLen : i + 4;
    return _VidPacket(i, payloadStart, hasAf, afFlags, afStart);
  }
  return null;
}

/// 从 [ts] 中第一个视频 PES 包解码 33 位 PTS。
///
/// `_encodePts` 的逆过程：PES 前缀 `00 00 01 E0`、2 字节长度、可选头部
///（`0x80`、PTS_DTS_flags、header_len），随后是 5 个 PTS 字节。
int firstPts(Uint8List ts) {
  final pkt = _firstVideoPacket(ts);
  if (pkt == null) throw StateError('no video PES packet');
  var p = pkt.payloadStart;
  // 在该包载荷中定位 PES 起始前缀。
  while (p + 14 < ts.length &&
      !(ts[p] == 0x00 && ts[p + 1] == 0x00 && ts[p + 2] == 0x01)) {
    p++;
  }
  final ptsStart = p + 9; // 6 (前缀+len) + 3 (参数,参数,hdr_len)
  final b0 = ts[ptsStart];
  final b1 = ts[ptsStart + 1];
  final b2 = ts[ptsStart + 2];
  final b3 = ts[ptsStart + 3];
  final b4 = ts[ptsStart + 4];
  return ((b0 >> 1) & 0x07) << 30 |
      b1 << 22 |
      ((b2 >> 1) & 0x7F) << 15 |
      b3 << 7 |
      ((b4 >> 1) & 0x7F);
}

/// 从第一个视频包的 adaptation 字段解码 33 位 PCR base；若该包未携带 PCR 则返回 null。
/// 这是 `_encodePcr` 的逆过程。
int? firstPcrBase(Uint8List ts) {
  final pkt = _firstVideoPacket(ts);
  if (pkt == null || !pkt.hasAf) return null;
  if ((pkt.afFlags & 0x10) == 0) return null; // PCR_flag 未设置。
  final b = pkt.afStart + 1; // 第一个 PCR 字节，位于标志字节之后。
  return ts[b] << 25 |
      ts[b + 1] << 17 |
      ts[b + 2] << 9 |
      ts[b + 3] << 1 |
      ((ts[b + 4] >> 7) & 0x01);
}

void main() {
  group('MpegTsMuxer', () {
    test('emits 188-byte aligned packets all starting with sync 0x47', () {
      final muxer = MpegTsMuxer();
      // SPS(7) + PPS(8) + IDR(5，first_mb=0 -> 最高位设置)，然后用一个 P 帧关闭访问单元。
      final out = BytesBuilder()
        ..add(muxer.addAnnexB(cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]), // 0x88 -> 最高位设置 => first_mb_in_slice 0。
          nal(1, [0x88, 0x01]), // 下一张图像 -> 刷新关键帧 AU。
        ])))
        ..add(muxer.flush());
      final ts = out.toBytes();

      expect(ts.length % 188, 0, reason: 'not packet-aligned');
      for (var i = 0; i < ts.length; i += 188) {
        expect(ts[i], 0x47, reason: 'packet at $i lacks sync byte');
      }
    });

    test('produces a PAT and a PMT before the keyframe', () {
      final muxer = MpegTsMuxer();
      final ts = cat([
        muxer.addAnnexB(cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]),
          nal(1, [0x88, 0x01]),
        ])),
        muxer.flush(),
      ]);

      expect(tsHasPat(ts), isTrue, reason: 'no PAT emitted');

      // PMT 位于 PID 0x1000，并带有 payload-unit-start 指示器。
      var sawPmt = false;
      for (var i = 0; i + 3 < ts.length; i += 188) {
        final pusi = (ts[i + 1] & 0x40) != 0;
        final pid = ((ts[i + 1] & 0x1F) << 8) | ts[i + 2];
        if (pusi && pid == 0x1000) sawPmt = true;
      }
      expect(sawPmt, isTrue, reason: 'no PMT emitted');
    });

    test('a multi-slice IDR stays a single access unit (one PAT)', () {
      final muxer = MpegTsMuxer();
      // SPS+PPS + 3 个 IDR slice：只有第一个 slice 的 first_mb==0（最高位设置）；
      // 其余 slice 延续同一张图像（最高位清空）。
      final ts = cat([
        muxer.addAnnexB(cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]), // 第一个 slice，first_mb == 0。
          nal(5, [0x20, 0x84]), // 后续 slice，first_mb != 0。
          nal(5, [0x20, 0x84]), // 后续 slice，first_mb != 0。
          nal(1, [0x88, 0x01]), // 下一张图像 -> 关闭 IDR AU。
        ])),
        muxer.flush(),
      ]);

      var patCount = 0;
      for (var i = 0; i + 3 < ts.length; i += 188) {
        final pusi = (ts[i + 1] & 0x40) != 0;
        final pid = ((ts[i + 1] & 0x1F) << 8) | ts[i + 2];
        if (pusi && pid == 0) patCount++;
      }
      expect(patCount, 1, reason: 'IDR slices were split into multiple AUs');
    });

    test('tsHasPat is false for raw Annex-B', () {
      final raw = cat([
        nal(7, [0x42, 0x00, 0x0a]),
        nal(5, [0x88, 0x84]),
      ]);
      expect(tsHasPat(raw), isFalse);
    });
  });

  group('MpegTsMuxer wall-clock PTS', () {
    // 封装器只有在下一个 AU 的前导 NAL 到达时才发出当前访问单元；
    // 单独的 AU 会保持缓冲直到 flush。因此要发出 AU_i，需要继续送入 picture_{i+1}。
    // 时钟在送入时采样，第一个已发出 AU 锚定 t0（PTS 0），后续 PTS 增量等于送入间距。

    /// 一张独立图像：SPS+PPS+IDR。前导 SPS 会刷新前一个 AU，IDR 让每个 AU 都是关键帧。
    Uint8List picture() => cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]),
        ]);

    /// 按给定到达时间（毫秒）送入图像，然后 flush，并按顺序返回每个已发出 AU 的 PTS。
    List<int> pumpPts(FakeClock clock, MpegTsMuxer muxer, List<int> arrivalsMs) {
      final out = <int>[];
      for (final ms in arrivalsMs) {
        clock.micros = ms * 1000;
        final ts = muxer.addAnnexB(picture());
        if (ts.isNotEmpty) out.add(firstPts(ts));
      }
      final tail = muxer.flush();
      if (tail.isNotEmpty) out.add(firstPts(tail));
      return out;
    }

    test('PTS tracks injected arrival time, not a fixed 60fps increment', () {
      final clock = FakeClock();
      final muxer = MpegTsMuxer(elapsedMicros: clock.call);

      // 以 50ms 间距送入（真实约 20fps），而不是固定 60fps 的 16.67ms 假设。
      final pts = pumpPts(clock, muxer, [0, 50, 100, 150]);

      expect(pts.length, greaterThanOrEqualTo(3));
      expect(pts.first, 0, reason: 'first emitted AU must anchor PTS 0');
      final d1 = pts[1] - pts[0];
      final d2 = pts[2] - pts[1];
      // 50ms * 90kHz = 每个 AU 4500 ticks，来自到达速率而不是固定 1500。
      expect(d1, closeTo(4500, 100), reason: 'PTS must track 50ms arrival');
      expect(d2, closeTo(4500, 100), reason: 'PTS must track 50ms arrival');
      expect(d1, isNot(closeTo(1500, 200)),
          reason: 'must NOT be the fixed 60fps increment (1500)');
    });

    test('PTS is strictly increasing when AUs share a tick (min spacing)', () {
      final clock = FakeClock(); // 永不推进：所有输入都在 t=0。
      final muxer = MpegTsMuxer(elapsedMicros: clock.call);

      final pts = pumpPts(clock, muxer, [0, 0, 0, 0]);

      expect(pts.length, greaterThanOrEqualTo(2));
      for (var i = 1; i < pts.length; i++) {
        expect(pts[i], greaterThan(pts[i - 1]),
            reason: 'minimum spacing must force a strict increase');
      }
    });

    test('an absurd forward jump from a stalled source is clamped', () {
      final clock = FakeClock();
      final muxer = MpegTsMuxer(elapsedMicros: clock.call);

      // AU0 在 t=0 发出并锚定 t0，AU1 之前经历 60s 停顿。
      final pts = pumpPts(clock, muxer, [0, 0, 60000]);

      expect(pts.length, greaterThanOrEqualTo(2));
      expect(pts.first, 0);
      // 进入停顿后 AU 的增量必须被限制在 _maxDelta（5s @ 90kHz = 450000），
      // 而不是原始 60s 增量产生的约 5.4M。
      final maxDelta = pts.reduce((a, b) => (b - a) > 0 ? (b - a) : 0);
      expect(maxDelta, lessThanOrEqualTo(450000),
          reason: 'single inter-AU delta must be capped at _maxDelta');
    });

    test('PCR on the keyframe packet equals that AU PTS (one clock)', () {
      final clock = FakeClock();
      final muxer = MpegTsMuxer(elapsedMicros: clock.call);

      // 送入一张图像后 flush，确保关键帧 AU 实际发出。
      final ts = (muxer..addAnnexB(picture())).flush();

      final pcr = firstPcrBase(ts);
      expect(pcr, isNotNull, reason: 'keyframe packet must carry PCR');
      expect(pcr, firstPts(ts),
          reason: 'PCR and PTS must be reads of the same clock');
    });
  });
}
