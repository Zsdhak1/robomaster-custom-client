/// Minimal MPEG-TS muxer that wraps a raw H.264 or H.265 Annex‑B byte stream
/// into a single-program transport stream, on the fly, for live playback.
///
/// WHY: media_kit's bundled libmpv ships WITHOUT the raw-H.264 lavf demuxer
/// (it fails with "Unknown lavf format h264"), but ALWAYS has the `mpegts`
/// demuxer (HLS depends on it).  The same is largely true for raw HEVC — mpv
/// ships the `hevc` raw demuxer, but wrapping in TS gives a single codec-
/// agnostic fallback.  Wrapping the custom 0x0310 line in MPEG-TS therefore
/// makes it playable by media_kit regardless of H.264 or H.265 codec.  The
/// container only fixes DEMUXING; rendering is unchanged.
///
/// Design notes:
/// - Splits the byte stream into NAL units (Annex-B start codes preserved, as
///   both H.264-in-TS and H.265-in-TS use the byte-stream format), groups NALs
///   into access units, and emits one PES packet per access unit with a 90 kHz
///   PTS.
/// - Access-unit boundaries are detected without full slice-header parsing:
///   For H.264, first_mb_in_slice == 0 is detected via the top bit of the first
///   RBSP byte.  For HEVC, a new AU starts when a VCL NAL follows the previous
///   VCL NAL (or a leading non-VCL that belongs to the next AU), using the
///   nuh_layer_id continuity heuristic.
/// - PAT/PMT are emitted before every keyframe AU so a decoder can join the
///   stream at any IDR (mirrors standard broadcast TS).
/// - Baseline profile / main tier (the encoder's low-bitrate mode) has no
///   B-frames, so DTS is omitted (PTS only).
library;

import 'dart:typed_data';

import '../../features/settings/logic/settings_providers.dart';

/// PID carrying the video elementary stream.
const int _videoPid = 0x100;

/// PID carrying the Program Map Table.
const int _pmtPid = 0x1000;

/// H.264 stream_type in the PMT.
const int _streamTypeH264 = 0x1B;

/// H.265 (HEVC) stream_type in the PMT.
const int _streamTypeHevc = 0x24;

/// Wraps a continuous Annex-B H.264 or H.265 stream into MPEG-TS packets.
class MpegTsMuxer {
  /// Creates a muxer whose PTS/PCR derive from arrival wall-clock.
  ///
  /// PTS is sampled from a monotonic [Stopwatch] at each access unit, so the
  /// media timeline advances at the rate frames actually arrive — not at an
  /// assumed constant rate. A previous fixed `90000/fps` increment made PTS a
  /// function of AU count, so on a slower/variable live source the media clock
  /// raced ahead of real arrival and the player rebuffered periodically.
  ///
  /// [fps] is retained only as a fallback: it sets the minimum PTS spacing (so
  /// two AUs completing in the same tick still get strictly increasing PTS).
  /// [codec] selects the elementary stream type signalled in the PMT and the
  /// NAL‑unit‑type parsing rules.
  /// [elapsedMicros] is injectable for tests; defaults to a real Stopwatch so
  /// no wall-clock (`DateTime.now`) is used — the clock must be monotonic.
  MpegTsMuxer({
    int fps = 60,
    this.codec = CustomVideoCodec.h264,
    int Function()? elapsedMicros,
  })  : _fpsFallback = (fps <= 0 ? 60 : fps),
        _elapsedMicros = elapsedMicros ?? _defaultClock();

  /// The video codec being muxed.
  final CustomVideoCodec codec;

  /// Assumed fps, used only to derive [_minSpacing] and bound absurd jumps.
  final int _fpsFallback;

  /// Monotonic elapsed-microseconds source (injectable for tests).
  final int Function() _elapsedMicros;

  /// Minimum PTS spacing in 90 kHz ticks, so same-tick AUs still increase.
  late final int _minSpacing = (90000 ~/ (_fpsFallback * 2)).clamp(1, 90000);

  /// Cap on a single inter-AU PTS delta (stalled-then-resumed source): 5 s.
  static const int _maxDelta = 5 * 90000;

  /// Stopwatch reading of the FIRST emitted AU; PTS 0 anchors there.
  int? _t0Micros;

  /// Builds a monotonic microsecond clock backed by a started [Stopwatch].
  static int Function() _defaultClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMicroseconds;
  }

  // Continuity counters (4-bit, per PID).
  int _ccPat = 0;
  int _ccPmt = 0;
  int _ccVideo = 0;

  /// The last PTS emitted (90 kHz), for monotonicity and minimum spacing.
  int _pts = 0;

  /// Bytes received but not yet split into complete NAL units.
  final List<int> _pending = [];

  /// NAL units accumulated for the access unit currently being assembled.
  final List<Uint8List> _au = [];
  bool _auHasVcl = false;
  bool _auHasKeyframe = false;

  /// Feeds raw Annex-B [data] and returns the TS bytes for any access units
  /// that completed as a result (may be empty).
  Uint8List addAnnexB(Uint8List data) {
    _pending.addAll(data);
    final out = BytesBuilder();
    for (final nal in _extractNals()) {
      _processNal(nal, out);
    }
    return out.toBytes();
  }

  /// Emits the final in-progress access unit. Call when the stream ends.
  Uint8List flush() {
    final out = BytesBuilder();
    if (_au.isNotEmpty) _emitAccessUnit(out);
    return out.toBytes();
  }

  // --- NAL splitting (streaming, start codes preserved) ---

  List<Uint8List> _extractNals() {
    final p = _pending;
    final starts = <int>[];
    var i = 0;
    while (i + 3 <= p.length) {
      if (p[i] == 0 && p[i + 1] == 0 && p[i + 2] == 1) {
        starts.add(i);
        i += 3;
        continue;
      }
      if (i + 4 <= p.length &&
          p[i] == 0 &&
          p[i + 1] == 0 &&
          p[i + 2] == 0 &&
          p[i + 3] == 1) {
        starts.add(i);
        i += 4;
        continue;
      }
      i++;
    }
    if (starts.length < 2) return const [];
    final nals = <Uint8List>[];
    for (var k = 0; k < starts.length - 1; k++) {
      nals.add(Uint8List.fromList(p.sublist(starts[k], starts[k + 1])));
    }
    final tail = p.sublist(starts.last);
    _pending
      ..clear()
      ..addAll(tail);
    return nals;
  }

  void _processNal(Uint8List nal, BytesBuilder out) {
    final scLen = (nal[2] == 1) ? 3 : 4;
    if (nal.length <= scLen) return; // start code only — skip

    if (codec == CustomVideoCodec.h265) {
      _processNalHevc(nal, scLen, out);
    } else {
      _processNalH264(nal, scLen, out);
    }
  }

  // ---- H.264 NAL processing ----

  /// H.264 nal_unit_type for an IDR picture.
  static const int _h264NalIdr = 5;

  /// H.264 nal_unit_type for a Sequence Parameter Set.
  static const int _h264NalSps = 7;

  /// H.264 nal_unit_type for a Picture Parameter Set.
  static const int _h264NalPps = 8;

  /// H.264 nal_unit_type for an Access Unit Delimiter.
  static const int _h264NalAud = 9;

  /// H.264 nal_unit_type for SEI.
  static const int _h264NalSei = 6;

  void _processNalH264(Uint8List nal, int scLen, BytesBuilder out) {
    final type = nal[scLen] & 0x1F;
    final isVcl = type >= 1 && type <= 5;
    final firstSlice =
        isVcl && nal.length > scLen + 1 && (nal[scLen + 1] & 0x80) != 0;
    final leadingNonVcl =
        !isVcl && (type == _h264NalAud || type == _h264NalSps || type == _h264NalPps || type == _h264NalSei);
    // A new access unit begins only once the current AU already carries a
    // picture (a VCL NAL): either a first-slice VCL of the NEXT picture, or a
    // leading non-VCL (AUD/SPS/PPS/SEI) of the next AU. This keeps an AU's own
    // leading SPS/PPS and its multi-slice IDR together as ONE access unit.
    final startsNewAu =
        _au.isNotEmpty && _auHasVcl && (firstSlice || leadingNonVcl);
    if (startsNewAu) _emitAccessUnit(out);

    _au.add(nal);
    if (isVcl) _auHasVcl = true;
    if (type == _h264NalIdr || type == _h264NalSps) _auHasKeyframe = true;
  }

  // ---- HEVC NAL processing ----

  /// HEVC nal_unit_type for IDR_W_RADL.
  static const int _hevcNalIdrWRadl = 19;

  /// HEVC nal_unit_type for IDR_N_LP.
  static const int _hevcNalIdrNLp = 20;

  /// HEVC nal_unit_type for CRA_NUT (clean random access).
  static const int _hevcNalCra = 21;

  /// HEVC nal_unit_type for VPS.
  static const int _hevcNalVps = 32;

  /// HEVC nal_unit_type for SPS.
  static const int _hevcNalSps = 33;

  /// HEVC nal_unit_type for PPS.
  static const int _hevcNalPps = 34;

  /// HEVC nal_unit_type for AUD.
  static const int _hevcNalAud = 35;

  /// Minimum VCL NAL type in HEVC (TRAIL_N … RSV_VCL31 / IDR / CRA).
  static const int _hevcVclMin = 0;

  /// Maximum VCL NAL type in HEVC.
  static const int _hevcVclMax = 21;

  void _processNalHevc(Uint8List nal, int scLen, BytesBuilder out) {
    final type = (nal[scLen] >> 1) & 0x3F;
    final isVcl = type >= _hevcVclMin && type <= _hevcVclMax;
    // In HEVC, a new access unit starts when the next VCL NAL arrives after a
    // previous VCL NAL (the previous picture is complete). Leading non-VCL
    // (VPS/SPS/PPS/AUD) of the next picture also start a new AU.
    final leadingNonVcl = !isVcl &&
        (type == _hevcNalAud ||
            type == _hevcNalVps ||
            type == _hevcNalSps ||
            type == _hevcNalPps);
    final startsNewAu =
        _au.isNotEmpty && _auHasVcl && (isVcl || leadingNonVcl);
    if (startsNewAu) _emitAccessUnit(out);

    _au.add(nal);
    if (isVcl) _auHasVcl = true;
    if (type == _hevcNalIdrWRadl ||
        type == _hevcNalIdrNLp ||
        type == _hevcNalCra ||
        type == _hevcNalVps ||
        type == _hevcNalSps) {
      _auHasKeyframe = true;
    }
  }

  // --- Access unit -> PES -> TS ---

  void _emitAccessUnit(BytesBuilder out) {
    final payload = BytesBuilder();
    for (final nal in _au) {
      payload.add(nal);
    }
    final isKey = _auHasKeyframe;

    // Wall-clock PTS: sample the monotonic clock ONCE, here, at the instant the
    // access unit is complete (one AU = one presentation instant). Convert
    // µs → 90 kHz doing multiply-before-divide in 64-bit to avoid drift
    // (micros * 90000 / 1000000 == micros * 9 ~/ 100). The FIRST AU anchors the
    // timeline at PTS 0 (exempt from spacing/clamp). Later AUs guard
    // monotonicity + minimum spacing (same-tick AUs must still increase) and
    // clamp an absurd forward jump from a stalled-then-resumed source; the
    // value is kept in the 33-bit PTS space.
    final now = _elapsedMicros();
    final isFirst = _t0Micros == null;
    _t0Micros ??= now;
    var pts = ((now - _t0Micros!) * 9) ~/ 100;
    if (!isFirst) {
      if (pts < _pts + _minSpacing) pts = _pts + _minSpacing;
      if (pts > _pts + _maxDelta) pts = _pts + _maxDelta;
    }
    pts &= 0x1FFFFFFFF;
    _pts = pts;

    // Make the stream joinable at every keyframe.
    if (isKey) {
      out
        ..add(_buildPat())
        ..add(_buildPmt());
    }
    final pes = _buildPes(payload.toBytes(), pts);
    _packetizePes(pes, pts, withPcr: isKey, out: out);

    _au.clear();
    _auHasVcl = false;
    _auHasKeyframe = false;
  }

  Uint8List _buildPes(Uint8List esData, int pts) {
    final optional = <int>[
      0x80, // '10' marker bits, no scrambling/priority/etc.
      0x80, // PTS_DTS_flags = '10' (PTS only)
      5, // PES_header_data_length
      ..._encodePts(pts),
    ];
    final bodyLen = optional.length + esData.length;
    // PES_packet_length may be 0 (unbounded) for video; set it when it fits.
    final pesLen = bodyLen <= 0xFFFF ? bodyLen : 0;
    final out = BytesBuilder()
      ..add([0x00, 0x00, 0x01, 0xE0, (pesLen >> 8) & 0xFF, pesLen & 0xFF])
      ..add(optional)
      ..add(esData);
    return out.toBytes();
  }

  static List<int> _encodePts(int p) {
    return [
      0x20 | (((p >> 30) & 0x07) << 1) | 0x01,
      (p >> 22) & 0xFF,
      (((p >> 15) & 0x7F) << 1) | 0x01,
      (p >> 7) & 0xFF,
      ((p & 0x7F) << 1) | 0x01,
    ];
  }

  void _packetizePes(
    Uint8List pes,
    int pts, {
    required bool withPcr,
    required BytesBuilder out,
  }) {
    var offset = 0;
    var first = true;
    while (offset < pes.length) {
      final remaining = pes.length - offset;
      final pcrLen = (first && withPcr) ? 6 : 0;
      // Bytes available for payload if the only adaptation content is the PCR
      // (length byte + flags byte + PCR).
      final maxPayloadWithAf = 184 - (pcrLen > 0 ? (2 + pcrLen) : 0);

      int payloadBytes;
      var hasAf = pcrLen > 0;
      List<int> afContent = const [];
      if (remaining >= (hasAf ? maxPayloadWithAf : 184)) {
        // Packet fills with payload; adaptation field only if PCR is present.
        payloadBytes = hasAf ? maxPayloadWithAf : 184;
        if (hasAf) afContent = [0x10, ..._encodePcr(pts)]; // PCR_flag set
      } else {
        // Final packet: pad with adaptation-field stuffing to reach 188.
        hasAf = true;
        payloadBytes = remaining;
        final afLen = 184 - remaining - 1; // excludes the length byte itself
        final flags = pcrLen > 0 ? 0x10 : 0x00;
        final stuffing = afLen - 1 - pcrLen; // minus flags byte and PCR
        afContent = [
          flags,
          if (pcrLen > 0) ..._encodePcr(pts),
          ...List<int>.filled(stuffing < 0 ? 0 : stuffing, 0xFF),
        ];
      }

      final afc = hasAf ? 0x03 : 0x01;
      final pkt = BytesBuilder()
        ..add([
          0x47,
          (first ? 0x40 : 0x00) | ((_videoPid >> 8) & 0x1F),
          _videoPid & 0xFF,
          (afc << 4) | _ccVideo,
        ]);
      _ccVideo = (_ccVideo + 1) & 0x0F;
      if (hasAf) {
        pkt
          ..add([afContent.length])
          ..add(afContent);
      }
      pkt.add(pes.sublist(offset, offset + payloadBytes));
      out.add(pkt.toBytes());
      offset += payloadBytes;
      first = false;
    }
  }

  static List<int> _encodePcr(int base) {
    // 33-bit base, 6 reserved bits (all 1), 9-bit extension (0 here).
    return [
      (base >> 25) & 0xFF,
      (base >> 17) & 0xFF,
      (base >> 9) & 0xFF,
      (base >> 1) & 0xFF,
      ((base & 0x01) << 7) | 0x7E,
      0x00,
    ];
  }

  // --- PSI tables (each fits in one TS packet) ---

  Uint8List _buildPat() {
    final section = <int>[
      0x00, // table_id = program_association_section
      0xB0, 0x0D, // section_syntax_indicator + section_length (13)
      0x00, 0x01, // transport_stream_id
      0xC1, // version 0, current_next_indicator = 1
      0x00, 0x00, // section_number, last_section_number
      0x00, 0x01, // program_number 1
      0xE0 | ((_pmtPid >> 8) & 0x1F), _pmtPid & 0xFF, // program_map_PID
    ];
    return _buildPsiPacket(0x0000, section);
  }

  Uint8List _buildPmt() {
    final streamType =
        codec == CustomVideoCodec.h265 ? _streamTypeHevc : _streamTypeH264;
    final section = <int>[
      0x02, // table_id = TS_program_map_section
      0xB0, 0x12, // section_syntax_indicator + section_length (18)
      0x00, 0x01, // program_number
      0xC1, // version 0, current_next_indicator = 1
      0x00, 0x00, // section_number, last_section_number
      0xE0 | ((_videoPid >> 8) & 0x1F), _videoPid & 0xFF, // PCR_PID
      0xF0, 0x00, // program_info_length = 0
      streamType,
      0xE0 | ((_videoPid >> 8) & 0x1F), _videoPid & 0xFF, // elementary_PID
      0xF0, 0x00, // ES_info_length = 0
    ];
    return _buildPsiPacket(_pmtPid, section);
  }

  Uint8List _buildPsiPacket(int pid, List<int> sectionWithoutCrc) {
    final crc = _crc32Mpeg(sectionWithoutCrc);
    final payload = <int>[
      0x00, // pointer_field
      ...sectionWithoutCrc,
      (crc >> 24) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 8) & 0xFF,
      crc & 0xFF,
    ];
    final cc = pid == 0x0000 ? _ccPat : _ccPmt;
    final pkt = Uint8List(188)..fillRange(4, 188, 0xFF);
    pkt[0] = 0x47;
    pkt[1] = 0x40 | ((pid >> 8) & 0x1F); // payload-unit-start indicator set
    pkt[2] = pid & 0xFF;
    pkt[3] = 0x10 | cc; // payload only
    pkt.setRange(4, 4 + payload.length, payload);
    if (pid == 0x0000) {
      _ccPat = (_ccPat + 1) & 0x0F;
    } else {
      _ccPmt = (_ccPmt + 1) & 0x0F;
    }
    return pkt;
  }

  static int _crc32Mpeg(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc ^= b << 24;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x80000000) != 0) {
          crc = ((crc << 1) ^ 0x04C11DB7) & 0xFFFFFFFF;
        } else {
          crc = (crc << 1) & 0xFFFFFFFF;
        }
      }
    }
    return crc & 0xFFFFFFFF;
  }
}

/// Returns true if [data] contains an MPEG-TS Program Association Table packet
/// (PID 0 with the payload-unit-start indicator set).
///
/// Used as the custom line's keyframe gate when the bridge serves TS: the muxer
/// emits a PAT before every keyframe, so a PAT marks a clean join point.
bool tsHasPat(Uint8List data) {
  for (var i = 0; i + 3 < data.length; i++) {
    if (data[i] != 0x47) continue;
    final pusi = (data[i + 1] & 0x40) != 0;
    final pid = ((data[i + 1] & 0x1F) << 8) | data[i + 2];
    if (pusi && pid == 0) return true;
  }
  return false;
}
