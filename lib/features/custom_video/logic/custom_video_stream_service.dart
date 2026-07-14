/// 自定义图传链路（0x0310 / CustomByteBlock）的 H.264/H.265 流桥接。
///
/// 将有序 `CustomByteBlock` 块拼接为连续 AnnexB 字节流（H.264 或 H.265，由 [start] 选择），
/// 并通过独立回环 TCP 桥接提供给 media_kit / fvp 解码。
/// 该链路与官方 UDP 3334 / HEVC 链路完全隔离，拥有独立的 [AnnexbTcpServer] 实例，
/// 以及匹配当前编解码器的关键帧闸门。
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../core/video/h264_annexb_gate.dart';
import '../../../core/video/mpegts_muxer.dart';
import '../../../services/annexb_tcp_server.dart';
import '../../settings/logic/settings_providers.dart';

/// 等待首个关键帧时最多缓存的字节数。
///
/// SPS/PPS 可能跨越 300 字节 `CustomByteBlock` 边界，因此闸门要基于累计字节判断，
/// 不能只看单个块。该上限用于在永远等不到关键帧时限制内存，例如中途接入 GOP。
const int _maxGateBufferBytes = 64 * 1024;

/// 将来自 MQTT 的有序 H.264 或 H.265 块桥接为回环 TCP 流。
class CustomVideoStreamService {
  /// 创建带编解码器无关 [AnnexbTcpServer] 的服务。
///
  /// [bridge] 可注入以便测试；默认会创建新桥接，并在 [start] 时按当前编解码器更新关键帧闸门。
  CustomVideoStreamService({AnnexbTcpServer? bridge}) {
    _bridge = bridge ?? AnnexbTcpServer(parameterSetDetector: _detectGate);
  }

  late AnnexbTcpServer _bridge;

  /// 当前编解码器，每次 [start] 时设置。
  CustomVideoCodec _codec = CustomVideoCodec.h264;

  /// 服务输出流是否封装为 MPEG-TS，每次 [start] 时设置。
  bool _tsWrap = false;

  /// [_tsWrap] 开启时使用的当前封装器；原始模式下为 null。
  MpegTsMuxer? _muxer;

  /// 按编解码器分发的闸门检测器：H.264 使用 [h264HasParameterSet]，
  /// H.265 使用 [h265HasParameterSet]；TS 模式始终使用 [tsHasPat]。
  bool _detectGate(Uint8List data) =>
      _tsWrap ? tsHasPat(data) : _codec == CustomVideoCodec.h265
          ? h265HasParameterSet(data)
          : h264HasParameterSet(data);

  /// 将源字节块送入桥接的订阅。
  StreamSubscription<Uint8List>? _sub;

  /// 关键帧前累计字节，用于扫描跨块边界的参数集。
  final List<int> _gateBuffer = [];

  /// 关键帧闸门是否已经打开，打开后字节会直接转发。
  bool _gateOpen = false;

  /// 桥接是否正在运行。
  bool _running = false;

  /// 从源端接收的 `CustomByteBlock` 块总数（上游计数）。
///
  /// 该计数发生在关键帧闸门之前，可区分“完全没有 MQTT 数据”（保持 0）和
  /// “数据已到达但闸门或解码器卡住”（计数增加，但 [gateOpen] / [decoderClients] 仍为 false/0）。
  int _chunksReceived = 0;

  /// 从源端接收的总字节数（上游、闸门前）。
  int _bytesReceived = 0;

  /// 最近一个块到达的墙钟时间，用于检测流是否停滞。
  DateTime? _lastChunkAt;

  /// 自 [start] 起按 `nal_unit_type` 统计到的 NAL 单元数量。
///
  /// 键为编解码器专属类型：H.264 使用 5 位类型
  /// （1=非 IDR，5=IDR，7=SPS，8=PPS），HEVC 使用 6 位类型
  /// （1=TRAIL_R，19=IDR_W_RADL，20=IDR_N_LP，32=VPS，33=SPS，34=PPS）。
  /// 该统计基于切片后的字节流，可判断关键帧是否真的到达，
  /// 用来区分“链路没有发送关键帧”和“关键帧已到达但被错误打包破坏”。
  final Map<int, int> _nalCounts = {};

  /// 上一个块末尾保留的字节，使跨块边界拆开的起始码仍能被 NAL 扫描器识别。
  final List<int> _nalScanTail = [];

  /// 最近一次见到关键帧或参数集 NAL 的墙钟时间。
  DateTime? _lastKeyframeAt;

  /// 桥接当前是否正在运行。
  bool get isRunning => _running;

  /// 当前会话使用的编解码器。
  CustomVideoCodec get codec => _codec;

  /// 自 [start] 起从 MQTT 接收的块数（闸门前上游计数）。
  int get chunksReceived => _chunksReceived;

  /// 自 [start] 起从 MQTT 接收的字节数（闸门前上游计数）。
  int get bytesReceived => _bytesReceived;

  /// 解码器用于读取视频流的 URL；停止时为 null。
  String? get streamUrl => _bridge.streamUrl;

  /// 关键帧闸门是否已经打开。
  bool get gateOpen => _gateOpen;

  /// 已转发给解码器客户端的总帧数。
  int get framesForwarded => _bridge.framesForwarded;

  /// 已转发给解码器客户端的总字节数。
  int get bytesForwarded => _bridge.bytesForwarded;

  /// 已连接的解码器客户端数量。
  int get decoderClients => _bridge.clientCount;

  /// 服务输出流是否封装为 MPEG-TS（诊断用）。
  bool get tsWrap => _tsWrap;

  /// 关键帧闸门前缓冲区当前持有的字节数；闸门打开后为 0。
  int get gateBufferBytes => _gateBuffer.length;

  /// 切片后字节流中每个 `nal_unit_type` 的 NAL 单元计数。
  Map<int, int> get nalCounts => Map.unmodifiable(_nalCounts);

  // ---- H.264 NAL 类型辅助函数 ----

  /// H.264 IDR 关键帧 NAL 类型。
  static const int _h264NalIdr = 5;

  /// H.264 SPS 参数集 NAL 类型。
  static const int _h264NalSps = 7;

  /// H.264 非‑IDR 切片 NAL 类型。
  static const int _h264NalNonIdr = 1;

  // ---- H.265 (HEVC) NAL 类型辅助函数 ----

  /// HEVC IDR_W_RADL 关键帧 NAL 类型。
  static const int _hevcNalIdrWRadl = 19;

  /// HEVC IDR_N_LP 关键帧 NAL 类型。
  static const int _hevcNalIdrNLp = 20;

  /// HEVC SPS 参数集 NAL 类型。
  static const int _hevcNalSps = 33;

  /// HEVC VPS 参数集 NAL 类型。
  static const int _hevcNalVps = 32;

  /// HEVC TRAIL_R (非‑IDR) NAL 类型。
  static const int _hevcNalTrailR = 1;

  /// 自 [start] 起见到的 IDR 关键帧 NAL 单元总数（按编解码器解释）。
  int get keyframesSeen {
    if (_codec == CustomVideoCodec.h265) {
      return (_nalCounts[_hevcNalIdrWRadl] ?? 0) +
          (_nalCounts[_hevcNalIdrNLp] ?? 0);
    }
    return _nalCounts[_h264NalIdr] ?? 0;
  }

  /// 自 [start] 起见到的 SPS 参数集 NAL 单元总数（按编解码器解释）。
  int get spsSeen {
    if (_codec == CustomVideoCodec.h265) {
      return _nalCounts[_hevcNalSps] ?? 0;
    }
    return _nalCounts[_h264NalSps] ?? 0;
  }

  /// 自 [start] 起见到的 VPS NAL 单元总数；仅 HEVC 使用，H.264 始终为 0。
  int get vpsSeen => _nalCounts[_hevcNalVps] ?? 0;

  /// 自 [start] 起见到的非 IDR 切片 NAL 单元总数（按编解码器解释）。
  int get nonIdrSeen {
    if (_codec == CustomVideoCodec.h265) {
      return _nalCounts[_hevcNalTrailR] ?? 0;
    }
    return _nalCounts[_h264NalNonIdr] ?? 0;
  }

  /// 距离最近一个关键帧或参数集 NAL 的毫秒数；没有时为 null。
  int? get millisSinceLastKeyframe {
    final at = _lastKeyframeAt;
    if (at == null) return null;
    return DateTime.now().difference(at).inMilliseconds;
  }

  /// 等待首个关键帧期间桥接已缓冲的帧数。
  int get pendingFrames => _bridge.pendingCount;

  /// 距离最近一个块到达的毫秒数；尚未收到块时为 null。
///
  /// [isRunning] 为 true 时该值持续增长，表示 MQTT 数据流停滞；
  /// 可快速区分“解码器卡住”和“源端已停止发送”。
  int? get millisSinceLastChunk {
    final at = _lastChunkAt;
    if (at == null) return null;
    return DateTime.now().difference(at).inMilliseconds;
  }

  // ---------------------------------------------------------------
  // 20 秒流转储
  // ---------------------------------------------------------------

  /// 当前是否正在转储。
  bool _dumping = false;

  /// 单次转储期间用于累计原始字节流的缓冲区。
  final List<int> _dumpBuffer = [];

  /// 20 秒结束后以转储文件路径完成的 Completer。
  Completer<String>? _dumpCompleter;

  /// 20 秒后结束转储的定时器。
  Timer? _dumpTimer;

  /// 是否正在转储。
  bool get isDumping => _dumping;

  /// 启动一次 20 秒原始字节流转储。
///
  /// 此窗口内收到的每个块都会追加到内存缓冲区。20 秒后累计字节会写入应用文档目录下的
  /// `.h264` 或 `.hevc` 文件，返回的 Future 以该文件路径完成。
///
  /// 已经有转储运行时调用 [startDump] 是空操作，会返回已有 Future。调用 [stopDump] 可提前取消。
  Future<String> startDump() {
    if (_dumping) {
      return _dumpCompleter!.future;
    }
    _dumping = true;
    _dumpBuffer.clear();
    _dumpCompleter = Completer<String>();
    _dumpTimer = Timer(const Duration(seconds: 20), _finaliseDump);
    return _dumpCompleter!.future;
  }

  /// 取消进行中的转储，不写入任何数据。
  void stopDump() {
    if (!_dumping) return;
    _dumpTimer?.cancel();
    _dumpTimer = null;
    _dumpBuffer.clear();
    _dumping = false;
    _dumpCompleter?.completeError(StateError('dump cancelled'));
    _dumpCompleter = null;
  }

  /// 将累计的转储缓冲区写入带时间戳的文件。
  Future<void> _finaliseDump() async {
    _dumpTimer = null;
    _dumping = false;

    final data = Uint8List.fromList(_dumpBuffer);
    _dumpBuffer.clear();
    final completer = _dumpCompleter!;
    _dumpCompleter = null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final ext = _codec == CustomVideoCodec.h265 ? 'hevc' : 'h264';
      final file = File('${dir.path}/custom_video_dump_$ts.$ext');
      await file.writeAsBytes(data);
      completer.complete(file.path);
    } catch (e) {
      completer.completeError(e);
    }
  }

  /// 启动 TCP 桥接并开始转发 [chunk]。
///
  /// [tsWrap] 为 true 时，闸门后的流会先封装为 MPEG-TS 再对外提供，
  /// 让缺少原始 H.264 解复用器的 media_kit 也能播放。[codec] 用于选择对应的关键帧闸门和 NAL 扫描器。
  Future<void> start(
    Stream<Uint8List> chunks, {
    bool tsWrap = false,
    CustomVideoCodec codec = CustomVideoCodec.h264,
  }) async {
    if (_running) return;
    _codec = codec;
    _tsWrap = tsWrap;
    // 按当前编解码器重建桥接和闸门检测器。
    _bridge.stop();
    _bridge = AnnexbTcpServer(parameterSetDetector: _detectGate);
    _muxer = tsWrap ? MpegTsMuxer(codec: codec) : null;
    await _bridge.start();
    _gateOpen = false;
    _gateBuffer.clear();
    _chunksReceived = 0;
    _bytesReceived = 0;
    _lastChunkAt = null;
    _nalCounts.clear();
    _nalScanTail.clear();
    _lastKeyframeAt = null;
    _sub = chunks.listen(_onChunk);
    _running = true;
  }

  /// 停止转发并释放桥接。
  void stop() {
    _sub?.cancel();
    _sub = null;
    _gateBuffer.clear();
    _gateOpen = false;
    _running = false;
    _muxer = null;
    _lastChunkAt = null;
    _bridge.stop();

    // 取消任何进行中的转储，不写入文件。
    _dumpTimer?.cancel();
    _dumpTimer = null;
    _dumpBuffer.clear();
    if (_dumping) {
      _dumping = false;
      _dumpCompleter?.completeError(StateError('service stopped'));
      _dumpCompleter = null;
    }
  }

  /// 释放所有资源。
  void dispose() => stop();

  void _onChunk(Uint8List chunk) {
    _chunksReceived++;
    _bytesReceived += chunk.length;
    _lastChunkAt = DateTime.now();

    // 统计切片后字节流中的 NAL 类型，让调试面板能判断关键帧是否实际到达。
    _scanNalUnits(chunk);

    // 闸门前就写入转储缓冲区，确保看到的是实际接收到的原始流，
    // 包括关键帧闸门尚未打开时的字节。
    if (_dumping) {
      _dumpBuffer.addAll(chunk);
    }

    if (_gateOpen) {
      _feed(chunk);
      return;
    }

    _gateBuffer.addAll(chunk);
    if (_gateBuffer.length > _maxGateBufferBytes) {
      _gateBuffer.removeRange(0, _gateBuffer.length - _maxGateBufferBytes);
    }

    final buffered = Uint8List.fromList(_gateBuffer);
    // 在封装前基于原始参数集打开闸门，确保桥接从解码器需要的 SPS/PPS
    // 或 HEVC 的 VPS/SPS/PPS 位置开始输出。
    if (_codec == CustomVideoCodec.h265
        ? h265HasParameterSet(buffered)
        : h264HasParameterSet(buffered)) {
      _feed(buffered);
      _gateBuffer.clear();
      _gateOpen = true;
    }
  }

  /// 将 [annexb] 转发到桥接；启用时先封装为 MPEG-TS。
  void _feed(Uint8List annexb) {
    final muxer = _muxer;
    if (muxer == null) {
      _bridge.feedFrame(annexb);
      return;
    }
    final ts = muxer.addAnnexB(annexb);
    if (ts.isNotEmpty) _bridge.feedFrame(ts);
  }

  /// 统计 [chunk] 中的 NAL 单元类型，并处理跨块边界的起始码。
///
  /// 遍历 3 字节或 4 字节 AnnexB 起始码，并从后续字节读取编解码器专属
  /// `nal_unit_type`：H.264 使用 5 位，HEVC 使用 6 位。函数会在当前块前拼接上一块的短尾部，
  /// 让跨边界拆开的起始码仍能被准确统计一次。
  void _scanNalUnits(Uint8List chunk) {
    // 最多拼接 3 个携带字节，以便统计跨边界的起始码。
    final buf = _nalScanTail.isEmpty
        ? chunk
        : Uint8List.fromList([..._nalScanTail, ...chunk]);
    final n = buf.length;
    final isHevc = _codec == CustomVideoCodec.h265;
    var i = 0;
    while (i + 3 < n) {
      final isLong = buf[i] == 0 &&
          buf[i + 1] == 0 &&
          buf[i + 2] == 0 &&
          buf[i + 3] == 1;
      final isShort = buf[i] == 0 && buf[i + 1] == 0 && buf[i + 2] == 1;
      if (isLong || isShort) {
        final hdr = i + (isLong ? 4 : 3);
        if (hdr < n) {
          // HEVC 使用 6 位 nal_unit_type；H.264 使用 5 位 nal_unit_type。
          final nalType = isHevc ? (buf[hdr] >> 1) & 0x3F : buf[hdr] & 0x1F;
          _nalCounts[nalType] = (_nalCounts[nalType] ?? 0) + 1;
          // 记录最近关键帧或参数集时间戳。
          if (_isKeyframeOrParam(nalType)) {
            _lastKeyframeAt = DateTime.now();
          }
        }
        i = hdr;
      } else {
        i++;
      }
    }
    // 携带最后 3 个字节，避免跨到下一个块的起始码漏检。
    _nalScanTail
      ..clear()
      ..addAll(buf.sublist(n >= 3 ? n - 3 : 0));
  }

  /// 当前编解码器下，[nalType] 是否表示关键帧或参数集 NAL。
  bool _isKeyframeOrParam(int nalType) {
    if (_codec == CustomVideoCodec.h265) {
      return nalType == _hevcNalIdrWRadl ||
          nalType == _hevcNalIdrNLp ||
          nalType == _hevcNalVps ||
          nalType == _hevcNalSps;
    }
    return nalType == _h264NalIdr ||
        nalType == _h264NalSps;
  }
}
