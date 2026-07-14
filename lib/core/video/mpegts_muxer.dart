/// 最小 MPEG-TS 封装器，用于将原始 H.264 或 H.265 AnnexB 字节流实时包装为
/// 单节目传输流。
///
/// 原因：media_kit 捆绑的 libmpv 通常没有内置原始 H.264 的 lavf 解复用器
/// （会报“未知 lavf 格式 h264”），但基本都会包含 `mpegts` 解复用器（HLS 依赖它）。
/// 原始 HEVC 的情况也类似；即使 mpv 内置 `hevc` 原始解复用器，包装成 TS 也能提供
/// 与具体编码格式无关的降级路径。因此，将自定义 0x0310 链路包装成 MPEG-TS 后，
/// 无论内容是 H.264 还是 H.265，media_kit 都能播放。容器只解决解复用问题，不改变渲染。
///
/// 设计说明：
/// - 将字节流拆分为 NAL 单元，并保留 AnnexB 起始码。H.264-in-TS 与 H.265-in-TS
///   都使用 byte-stream 格式；多个 NAL 会聚合为访问单元，每个访问单元输出一个
///   带 90 kHz PTS 的 PES 包。
/// - 访问单元边界不做完整 slice-header 解析。H.264 通过首个 RBSP 字节的高位识别
///   `first_mb_in_slice == 0`；HEVC 在一个 VCL NAL 跟随前一个 VCL NAL，或属于下一帧
///   的前导非 VCL NAL 出现时开启新 AU。
/// - 每个关键帧 AU 前都会重新发出 PAT/PMT，让解码器可以从任意 IDR 加入流。
/// - 低码率模式没有 B 帧，因此只写 PTS，不写 DTS。
library;

import 'dart:typed_data';

import '../../features/settings/logic/settings_providers.dart';

/// 承载视频基本流的 PID。
const int _videoPid = 0x100;

/// 承载 Program Map Table 的 PID。
const int _pmtPid = 0x1000;

/// PMT 中表示 H.264 的 stream_type。
const int _streamTypeH264 = 0x1B;

/// PMT 中表示 H.265（HEVC）的 stream_type。
const int _streamTypeHevc = 0x24;

/// 将连续 AnnexB H.264 或 H.265 流包装为 MPEG-TS 包。
class MpegTsMuxer {
  /// 创建 PTS/PCR 基于到达时间派生的封装器。
  ///
  /// 每个访问单元完成时都会从单调 [Stopwatch] 采样 PTS，因此媒体时间线按照帧的
  /// 实际到达速度推进，而不是假设恒定帧率。旧版固定使用 `90000 / 帧率` 递增 PTS，
  /// 会让慢速或抖动的实时源里媒体时钟跑在真实到达时间前面，导致播放器周期性缓冲。
  ///
  /// [frameRate] 仅作为降级参数使用：它决定最小 PTS 间距，确保同一时钟 tick 完成的
  /// 两个 AU 仍能获得严格递增的 PTS。[codec] 决定 PMT 中声明的基本流类型以及
  /// NAL 单元类型解析规则。[elapsedMicros] 可在测试中注入；默认使用真实 [Stopwatch]，
  /// 不依赖墙钟时间，保证时钟单调。
  MpegTsMuxer({
    int fps = 60,
    this.codec = CustomVideoCodec.h264,
    int Function()? elapsedMicros,
  })  : _fpsFallback = (fps <= 0 ? 60 : fps),
        _elapsedMicros = elapsedMicros ?? _defaultClock();

  /// 当前封装的视频编码格式。
  final CustomVideoCodec codec;

  /// 假定帧率，仅用于派生 [_minSpacing] 并限制异常跳变。
  final int _fpsFallback;

  /// 单调递增的微秒时钟源，可在测试中注入。
  final int Function() _elapsedMicros;

  /// 90 kHz tick 下的最小 PTS 间距，确保同 tick AU 仍然递增。
  late final int _minSpacing = (90000 ~/ (_fpsFallback * 2)).clamp(1, 90000);

  /// 单个 AU 间 PTS 增量上限，用于限制暂停后恢复的异常跳变：5 秒。
  static const int _maxDelta = 5 * 90000;

  /// 第一个已发出 AU 的 Stopwatch 读数，作为 PTS 0 锚点。
  int? _t0Micros;

  /// 构建由已启动 [Stopwatch] 驱动的单调微秒时钟。
  static int Function() _defaultClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsedMicroseconds;
  }

  // 连续性计数器（4 位，每个 PID 独立）。
  int _ccPat = 0;
  int _ccPmt = 0;
  int _ccVideo = 0;

  /// 最后一次发出的 PTS（90 kHz），用于保证单调递增和最小间距。
  int _pts = 0;

  /// 已接收但尚未拆分为完整 NAL 单元的字节。
  final List<int> _pending = [];

  /// 当前正在组装的访问单元累积的 NAL 单元。
  final List<Uint8List> _au = [];
  bool _auHasVcl = false;
  bool _auHasKeyframe = false;

  /// 送入原始 AnnexB [data]，返回因此完成的访问单元对应的 TS 字节。
  ///
  /// 返回值可能为空，表示当前数据还不足以形成完整访问单元。
  Uint8List addAnnexB(Uint8List data) {
    _pending.addAll(data);
    final out = BytesBuilder();
    for (final nal in _extractNals()) {
      _processNal(nal, out);
    }
    return out.toBytes();
  }

  /// 发出最后一个进行中的访问单元；应在流结束时调用。
  Uint8List flush() {
    final out = BytesBuilder();
    if (_au.isNotEmpty) _emitAccessUnit(out);
    return out.toBytes();
  }

  // --- NAL 流式拆分（保留起始码）---

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
    if (nal.length <= scLen) return; // 只有起始码，直接跳过。

    if (codec == CustomVideoCodec.h265) {
      _processNalHevc(nal, scLen, out);
    } else {
      _processNalH264(nal, scLen, out);
    }
  }

  // ---- H.264 NAL 处理 ----

  /// H.264 IDR 图像的 `nal_unit_type`。
  static const int _h264NalIdr = 5;

  /// H.264 序列参数集的 `nal_unit_type`。
  static const int _h264NalSps = 7;

  /// H.264 图像参数集的 `nal_unit_type`。
  static const int _h264NalPps = 8;

  /// H.264 访问单元分隔符的 `nal_unit_type`。
  static const int _h264NalAud = 9;

  /// H.264 SEI 的 `nal_unit_type`。
  static const int _h264NalSei = 6;

  void _processNalH264(Uint8List nal, int scLen, BytesBuilder out) {
    final type = nal[scLen] & 0x1F;
    final isVcl = type >= 1 && type <= 5;
    final firstSlice =
        isVcl && nal.length > scLen + 1 && (nal[scLen + 1] & 0x80) != 0;
    final leadingNonVcl =
        !isVcl && (type == _h264NalAud || type == _h264NalSps || type == _h264NalPps || type == _h264NalSei);
    // 只有当前 AU 已经携带图像（VCL NAL）后，才允许开启新访问单元：
    // 触发条件要么是下一帧的 first-slice VCL，要么是下一 AU 的前导非 VCL
    // （AUD/SPS/PPS/SEI）。这样可以把当前 AU 自己的前导 SPS/PPS 与多 slice IDR
    // 保持在同一个访问单元内。
    final startsNewAu =
        _au.isNotEmpty && _auHasVcl && (firstSlice || leadingNonVcl);
    if (startsNewAu) _emitAccessUnit(out);

    _au.add(nal);
    if (isVcl) _auHasVcl = true;
    if (type == _h264NalIdr || type == _h264NalSps) _auHasKeyframe = true;
  }

  // ---- HEVC NAL 处理 ----

  /// HEVC IDR_W_RADL 的 `nal_unit_type`。
  static const int _hevcNalIdrWRadl = 19;

  /// HEVC IDR_N_LP 的 `nal_unit_type`。
  static const int _hevcNalIdrNLp = 20;

  /// HEVC CRA_NUT（干净随机访问）的 `nal_unit_type`。
  static const int _hevcNalCra = 21;

  /// HEVC VPS 的 `nal_unit_type`。
  static const int _hevcNalVps = 32;

  /// HEVC SPS 的 `nal_unit_type`。
  static const int _hevcNalSps = 33;

  /// HEVC PPS 的 `nal_unit_type`。
  static const int _hevcNalPps = 34;

  /// HEVC AUD 的 `nal_unit_type`。
  static const int _hevcNalAud = 35;

  /// HEVC 中最小的 VCL NAL 类型（TRAIL_N 到 RSV_VCL31 / IDR / CRA）。
  static const int _hevcVclMin = 0;

  /// HEVC 中最大的 VCL NAL 类型。
  static const int _hevcVclMax = 21;

  void _processNalHevc(Uint8List nal, int scLen, BytesBuilder out) {
    final type = (nal[scLen] >> 1) & 0x3F;
    final isVcl = type >= _hevcVclMin && type <= _hevcVclMax;
    // 在 HEVC 中，一个 VCL NAL 出现在前一个 VCL NAL 之后表示前一帧完成，
    // 可以开启新的访问单元。下一帧的前导非 VCL（VPS/SPS/PPS/AUD）也会开启新 AU。
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

  // --- 访问单元 -> PES -> TS ---

  void _emitAccessUnit(BytesBuilder out) {
    final payload = BytesBuilder();
    for (final nal in _au) {
      payload.add(nal);
    }
    final isKey = _auHasKeyframe;

    // 到达时间 PTS：访问单元完成时采样一次单调时钟（一个 AU 对应一个呈现时刻）。
    // 微秒到 90 kHz 的换算先乘后除，避免漂移：
    // micros * 90000 / 1000000 == micros * 9 ~/ 100。
    // 第一个 AU 将时间线锚定在 PTS 0，不参与间距和钳制；后续 AU 保证单调递增、
    // 最小间距，并限制暂停后恢复导致的异常前跳。最终值保留在 33 位 PTS 空间内。
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

    // 每个关键帧前补发 PAT/PMT，使播放器可以从关键帧加入流。
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
      0x80, // `10` 标记位，无加扰、优先级等附加标志。
      0x80, // PTS_DTS_flags = `10`，仅携带 PTS。
      5, // PES 可选头部数据长度。
      ..._encodePts(pts),
    ];
    final bodyLen = optional.length + esData.length;
    // 视频 PES_packet_length 可为 0（无界）；能装入 16 位时才写入实际长度。
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
      // adaptation field 仅携带 PCR 时，剩余可用于负载的字节数
      // （长度字节 + 标志字节 + PCR）。
      final maxPayloadWithAf = 184 - (pcrLen > 0 ? (2 + pcrLen) : 0);

      int payloadBytes;
      var hasAf = pcrLen > 0;
      List<int> afContent = const [];
      if (remaining >= (hasAf ? maxPayloadWithAf : 184)) {
        // 包由负载填满；只有需要 PCR 时才保留 adaptation field。
        payloadBytes = hasAf ? maxPayloadWithAf : 184;
        if (hasAf) afContent = [0x10, ..._encodePcr(pts)]; // 设置 PCR_flag。
      } else {
        // 最后一个包：用 adaptation field 填充到 188 字节。
        hasAf = true;
        payloadBytes = remaining;
        final afLen = 184 - remaining - 1; // 不包含长度字节本身。
        final flags = pcrLen > 0 ? 0x10 : 0x00;
        final stuffing = afLen - 1 - pcrLen; // 扣除标志字节和 PCR。
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
    // 33 位基准值，6 位保留位（全 1），9 位扩展值（这里为 0）。
    return [
      (base >> 25) & 0xFF,
      (base >> 17) & 0xFF,
      (base >> 9) & 0xFF,
      (base >> 1) & 0xFF,
      ((base & 0x01) << 7) | 0x7E,
      0x00,
    ];
  }

  // --- PSI 表（每个表都能放入一个 TS 包）---

  Uint8List _buildPat() {
    final section = <int>[
      0x00, // PAT 表 ID。
      0xB0, 0x0D, // 段语法标志 + 段长度（13）。
      0x00, 0x01, // 传输流 ID。
      0xC1, // 版本 0，current_next_indicator = 1
      0x00, 0x00, // 段号与最后段号。
      0x00, 0x01, // 节目号 1。
      0xE0 | ((_pmtPid >> 8) & 0x1F), _pmtPid & 0xFF, // PMT PID。
    ];
    return _buildPsiPacket(0x0000, section);
  }

  Uint8List _buildPmt() {
    final streamType =
        codec == CustomVideoCodec.h265 ? _streamTypeHevc : _streamTypeH264;
    final section = <int>[
      0x02, // PMT 表 ID。
      0xB0, 0x12, // 段语法标志 + 段长度（18）。
      0x00, 0x01, // 节目号。
      0xC1, // 版本 0，current_next_indicator = 1
      0x00, 0x00, // 段号与最后段号。
      0xE0 | ((_videoPid >> 8) & 0x1F), _videoPid & 0xFF, // PCR PID。
      0xF0, 0x00, // 节目信息长度为 0。
      streamType,
      0xE0 | ((_videoPid >> 8) & 0x1F), _videoPid & 0xFF, // 基本流 PID。
      0xF0, 0x00, // 基本流信息长度为 0。
    ];
    return _buildPsiPacket(_pmtPid, section);
  }

  Uint8List _buildPsiPacket(int pid, List<int> sectionWithoutCrc) {
    final crc = _crc32Mpeg(sectionWithoutCrc);
    final payload = <int>[
      0x00, // 指针字段。
      ...sectionWithoutCrc,
      (crc >> 24) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 8) & 0xFF,
      crc & 0xFF,
    ];
    final cc = pid == 0x0000 ? _ccPat : _ccPmt;
    final pkt = Uint8List(188)..fillRange(4, 188, 0xFF);
    pkt[0] = 0x47;
    pkt[1] = 0x40 | ((pid >> 8) & 0x1F); // 设置 payload_unit_start_indicator。
    pkt[2] = pid & 0xFF;
    pkt[3] = 0x10 | cc; // 仅负载。
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

/// 当 [data] 包含 MPEG-TS Program Association Table 包时返回 true。
///
/// 这里检查 PID 0 且设置了 payload_unit_start_indicator 的包。桥接输出 TS 时，
/// 该函数作为自定义链路的关键帧闸门使用：封装器会在每个关键帧前发出 PAT，
/// 因此 PAT 可视为干净的加入点。
bool tsHasPat(Uint8List data) {
  for (var i = 0; i + 3 < data.length; i++) {
    if (data[i] != 0x47) continue;
    final pusi = (data[i + 1] & 0x40) != 0;
    final pid = ((data[i + 1] & 0x1F) << 8) | data[i + 2];
    if (pusi && pid == 0) return true;
  }
  return false;
}
