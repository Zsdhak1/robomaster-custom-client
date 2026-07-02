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

/// Advanceable monotonic fake clock in microseconds (no `DateTime.now`).
class FakeClock {
  int micros = 0;
  int call() => micros;
  void advanceMs(int ms) => micros += ms * 1000;
}

/// A parsed access unit's video-PID TS packet: byte offset of the packet and
/// where its payload starts (after the TS header and any adaptation field).
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

/// Finds the first video-PID (0x100) TS packet with the payload-unit-start
/// indicator set, returning packet/payload/adaptation-field offsets.
_VidPacket? _firstVideoPacket(Uint8List ts) {
  for (var i = 0; i + 188 <= ts.length; i += 188) {
    if (ts[i] != 0x47) continue;
    final pusi = (ts[i + 1] & 0x40) != 0;
    final pid = ((ts[i + 1] & 0x1F) << 8) | ts[i + 2];
    final afc = (ts[i + 3] >> 4) & 0x03;
    if (pid != 0x100 || !pusi) continue;
    final hasAf = afc == 0x02 || afc == 0x03;
    final afLen = hasAf ? ts[i + 4] : 0;
    final afStart = i + 5; // after the AF length byte
    final afFlags = (hasAf && afLen > 0) ? ts[afStart] : 0;
    // Payload starts after the 4-byte TS header and the AF (length byte + AF).
    final payloadStart = hasAf ? i + 5 + afLen : i + 4;
    return _VidPacket(i, payloadStart, hasAf, afFlags, afStart);
  }
  return null;
}

/// Decodes the 33-bit PTS from the first video PES packet in [ts].
///
/// Inverse of `_encodePts`: PES prefix `00 00 01 E0`, 2-byte length, optional
/// header (`0x80`, PTS_DTS_flags, header_len), then the 5 PTS bytes.
int firstPts(Uint8List ts) {
  final pkt = _firstVideoPacket(ts);
  if (pkt == null) throw StateError('no video PES packet');
  var p = pkt.payloadStart;
  // Locate the PES start prefix within this packet's payload.
  while (p + 14 < ts.length &&
      !(ts[p] == 0x00 && ts[p + 1] == 0x00 && ts[p + 2] == 0x01)) {
    p++;
  }
  final ptsStart = p + 9; // 6 (prefix+len) + 3 (flags,flags,hdr_len)
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

/// Decodes the 33-bit PCR base from the first video packet's adaptation field,
/// or null if that packet carries no PCR. Inverse of `_encodePcr`.
int? firstPcrBase(Uint8List ts) {
  final pkt = _firstVideoPacket(ts);
  if (pkt == null || !pkt.hasAf) return null;
  if ((pkt.afFlags & 0x10) == 0) return null; // PCR_flag not set
  final b = pkt.afStart + 1; // first PCR byte, after the flags byte
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

  group('MpegTsMuxer wall-clock PTS', () {
    // The muxer emits an access unit only when the NEXT AU's leading NAL
    // arrives (a lone AU stays buffered until flush). So to emit AU_i we feed
    // picture_{i+1}; the clock is sampled at that feed. The first emitted AU
    // anchors t0 (PTS 0), so PTS deltas equal the spacing between feeds.

    /// One independent picture: SPS+PPS+IDR (its leading SPS flushes the prior
    /// AU; the IDR makes each AU a keyframe).
    Uint8List picture() => cat([
          nal(7, [0x42, 0x00, 0x0a]),
          nal(8, [0xce]),
          nal(5, [0x88, 0x84]),
        ]);

    /// Feeds a picture at each arrival time (ms), then flushes, returning the
    /// PTS of every emitted access unit in order.
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

      // Feeds at 50 ms spacing (real ~20 fps), NOT the 16.67 ms a fixed 60fps
      // increment would assume.
      final pts = pumpPts(clock, muxer, [0, 50, 100, 150]);

      expect(pts.length, greaterThanOrEqualTo(3));
      expect(pts.first, 0, reason: 'first emitted AU must anchor PTS 0');
      final d1 = pts[1] - pts[0];
      final d2 = pts[2] - pts[1];
      // 50 ms * 90 kHz = 4500 ticks per AU — the arrival rate, not 1500.
      expect(d1, closeTo(4500, 100), reason: 'PTS must track 50ms arrival');
      expect(d2, closeTo(4500, 100), reason: 'PTS must track 50ms arrival');
      expect(d1, isNot(closeTo(1500, 200)),
          reason: 'must NOT be the fixed 60fps increment (1500)');
    });

    test('PTS is strictly increasing when AUs share a tick (min spacing)', () {
      final clock = FakeClock(); // never advances — all feeds at t=0
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

      // AU0 emitted at t=0 (anchors t0), AU1 after a 60 s stall.
      final pts = pumpPts(clock, muxer, [0, 0, 60000]);

      expect(pts.length, greaterThanOrEqualTo(2));
      expect(pts.first, 0);
      // The delta into the post-stall AU must be capped at _maxDelta
      // (5 s @ 90 kHz = 450000), not the ~5.4M a raw 60 s delta would give.
      final maxDelta = pts.reduce((a, b) => (b - a) > 0 ? (b - a) : 0);
      expect(maxDelta, lessThanOrEqualTo(450000),
          reason: 'single inter-AU delta must be capped at _maxDelta');
    });

    test('PCR on the keyframe packet equals that AU PTS (one clock)', () {
      final clock = FakeClock();
      final muxer = MpegTsMuxer(elapsedMicros: clock.call);

      // Feed one picture then flush so the keyframe AU is actually emitted.
      final ts = (muxer..addAnnexB(picture())).flush();

      final pcr = firstPcrBase(ts);
      expect(pcr, isNotNull, reason: 'keyframe packet must carry PCR');
      expect(pcr, firstPts(ts),
          reason: 'PCR and PTS must be reads of the same clock');
    });
  });
}
