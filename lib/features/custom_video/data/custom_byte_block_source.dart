/// 订阅 MQTT `CustomByteBlock` 主题，并发出每条消息携带的 H.264 AnnexB 字节块。
///
/// 线缆格式（当前机器人固件）：每个包的 `CustomByteBlock.data` 以 8 字节 uint64
/// 小端序序列号开头（每包递增 1，用于丢包检测），后面跟 H.264 载荷。载荷本身可能
/// 再带一个 protobuf 风格长度前缀（`0x0A <varint> <载荷> [padding]`），因此序列号
/// 之后的主体切片方式通过 [CustomVideoSliceMode] 配置，并且每包实时读取；设置变更
/// 会在下一个包立即生效，无需重启。
///
/// 这里刻意不使用 `is_frame_start` 标记做分帧。实测机器人并不可靠设置该标记，
/// 如果用它作为发送闸门，整条流可能被卡住而没有任何块被转发。
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/protobuf/protobuf_parser.dart';
import '../../../features/settings/logic/settings_providers.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import '../../../services/mqtt_service.dart';
import 'custom_packet_slicer.dart';
import 'packet_sequence_tracker.dart';

/// 发出通过 MQTT `CustomByteBlock` 接收到的 H.264 AnnexB 字节块。
class CustomByteBlockSource {
  /// 创建绑定到 [mqttService] 和 [parser] 的数据源。
  ///
  /// 切片行为通过实时回调提供，因此设置变更会在下一个包生效：
  /// - `sliceMode` 返回当前 [CustomVideoSliceMode]。
  /// - `headerBytes` / `payloadBytes` 在 [CustomVideoSliceMode.fixed] 下生效。
  /// - `seqHeaderEnabled` 控制是否解析并剥离用于丢包检测的前置 uint64 LE 序列号。
  CustomByteBlockSource({
    required this._mqttService,
    required this._parser,
    required this._sliceMode,
    required this._headerBytes,
    required this._payloadBytes,
    required this._seqHeaderEnabled,
  });

  final MqttService _mqttService;
  final ProtobufParser _parser;
  final CustomVideoSliceMode Function() _sliceMode;
  final int Function() _headerBytes;
  final int Function() _payloadBytes;
  final bool Function() _seqHeaderEnabled;

  StreamSubscription<({String topic, Uint8List payload})>? _mqttSub;
  final _chunkController = StreamController<Uint8List>.broadcast();

  /// 跟踪前置序列号，用于丢包报告。
  final _seqTracker = PacketSequenceTracker();

  // ---- 诊断数据（由调试面板读取）-----------------------------

  /// 该主题已接收的总包数。
  int packetsReceived = 0;

  /// 检测到 `0x0A <varint>` 前缀的包数（stripPrefix 模式）。
  int packetsWithPrefix = 0;

  /// 声明长度超过实际到达字节数的包数。
  ///
  /// 这通常表示上游存在链路或 MTU 截断问题。
  int packetsTruncated = 0;

  /// 最近一个包切片前的原始长度。
  int lastRawLength = 0;

  /// 最近一个包声明的载荷长度；无前缀时为 -1。
  int lastDeclaredLength = -1;

  /// 最近一个包的序列号（前置 8 字节 uint64 LE）。
  int get lastSequence => _seqTracker.lastSeq;

  /// 是否已经观察到至少一个序列号。
  bool get hasSequence => _seqTracker.hasData;

  /// 自 [start] 后通过序列号观察到的包数。
  int get seqPacketsSeen => _seqTracker.packetsSeen;

  /// 自 [start] 后从序列号间隔推断出的丢包数。
  int get packetsLost => _seqTracker.packetsLost;

  /// 自 [start] 起见到的乱序或重复序列号。
  int get seqRegressions => _seqTracker.regressions;

  /// 根据序列号范围推导出的丢包率，取值范围为 `[0, 1]`。
  double get lossRate => _seqTracker.lossRate;

  /// 数据源当前是否已订阅主题。
  bool get isSubscribed => _mqttSub != null;

  /// 从 `CustomByteBlock` 消息中提取出的 H.264 AnnexB 块流。
  Stream<Uint8List> get chunkStream => _chunkController.stream;

  /// 开始监听 [topicCustomByteBlock]；可重复调用。
  void start() {
    if (_mqttSub != null) return;
    packetsReceived = 0;
    packetsWithPrefix = 0;
    packetsTruncated = 0;
    _seqTracker.reset();
    _mqttService.subscribe(topicCustomByteBlock);
    _mqttSub = _mqttService.messageStream.listen(_onMqttMessage);
  }

  /// 停止监听并取消订阅主题。
  void stop() {
    _mqttSub?.cancel();
    _mqttSub = null;
    _mqttService.unsubscribe(topicCustomByteBlock);
  }

  /// 释放所有资源，包括广播 [chunkStream]。
  void dispose() {
    stop();
    _chunkController.close();
  }

  void _onMqttMessage(({String topic, Uint8List payload}) msg) {
    if (msg.topic != topicCustomByteBlock) return;

    final envelope = _parser.parse(msg.topic, msg.payload);
    final message = envelope.protobufMessage;
    if (message is! CustomByteBlock) return;

    final rawData = message.data;
    if (rawData.isEmpty) return;

    final data = Uint8List.fromList(rawData);
    packetsReceived++;
    lastRawLength = data.length;

    // 机器人会前置 8 字节 uint64 LE 序列号用于丢包检测。先观察并更新丢包计数，
    // 再剥离它，让切片器只看到带原始帧封装的 H.264 载荷。
    var body = data;
    if (_seqHeaderEnabled() && data.length >= customVideoSeqHeaderBytes) {
      _seqTracker.observe(data);
      body = Uint8List.sublistView(data, customVideoSeqHeaderBytes);
    }
    if (body.isEmpty) return;

    final SliceResult result;
    switch (_sliceMode()) {
      case CustomVideoSliceMode.verbatim:
        result = SliceResult(
          bytes: body,
          prefixBytes: 0,
          declaredLength: -1,
          prefixDetected: false,
        );
      case CustomVideoSliceMode.stripPrefix:
        result = stripVarintPrefix(body);
      case CustomVideoSliceMode.fixed:
        result = sliceFixed(body, _headerBytes(), _payloadBytes());
    }

    lastDeclaredLength = result.declaredLength;
    if (result.prefixDetected) packetsWithPrefix++;
    if (result.declaredLength > 0 &&
        result.declaredLength > body.length - result.prefixBytes) {
      packetsTruncated++;
    }

    if (result.bytes.isNotEmpty && !_chunkController.isClosed) {
      _chunkController.add(Uint8List.fromList(result.bytes));
    }
  }
}
