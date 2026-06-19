/// Structural tests for [MpegTsMuxer].
///
/// End-to-end decodability is validated separately with ffprobe/ffmpeg (the
/// muxer output of a real .h264 dump probes as a clean 400x400 h264 stream).
/// These tests lock the on-the-wire invariants that decoders rely on.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/video/mpegts_muxer.dart';

/// Builds an Annex-B NAL: 4-byte start code + 1-byte H.264 header + body.
Uint8List nal(int type, List<int> body) {
  return Uint8List.fromList([0, 0, 0, 1, type & 0x1F, ...body]);
}

/// Concatenates byte lists.
Uint8List cat(List<Uint8List> parts) {
  final b = BytesBuilder();
  for (final p in parts) {
    b.add(p);
  }
  return b.toBytes();
}

void main() {
  group('MpegTsMuxer', () {
    test('emits 188-byte aligned packets all starting with sync 0x47', () {
      final muxer = MpegTsMuxer();
      // SPS(7) + PPS(8) + IDR(5, first_mb=0 -> top bit set), then a P frame to
      // close the access unit.
      final out = BytesBuilder()
        ..add(muxer.addAnnexB(cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]), // 0x88 -> top bit set => first_mb_in_slice 0
          nal(1, [0x88, 0x01]), // next picture -> flushes the keyframe AU
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

      // PMT is on PID 0x1000 with the payload-unit-start indicator.
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
      // SPS+PPS + 3 IDR slices: only the FIRST slice has first_mb==0 (top bit
      // set); the others continue the same picture (top bit clear).
      final ts = cat([
        muxer.addAnnexB(cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]), // first slice, first_mb == 0
          nal(5, [0x20, 0x84]), // continued slice, first_mb != 0
          nal(5, [0x20, 0x84]), // continued slice, first_mb != 0
          nal(1, [0x88, 0x01]), // next picture -> closes the IDR AU
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
}
