/// UDP 3334 HEVC 视频帧重组器。
///
/// 解析 UDP 包头，按 [frameId] 缓存分片；
/// 当同一帧的所有分片到齐后输出完整 AnnexB 帧。
/// 超过 [frameReassemblyTimeout] 仍未完成的帧会被丢弃。
library;

import 'dart:async';
import 'dart:typed_data';

import '../constants/protocol_constants.dart';
import '../utils/byte_data_reader.dart';
import 'video_frame.dart';

/// 正在重组中的单帧缓存。
class _FrameBuffer {
  _FrameBuffer({
    required this.frameId,
    required this.frameSize,
    required this.firstPacketTime,
  });

  final int frameId;
  final int frameSize;
  final DateTime firstPacketTime;

  /// 已接收分片，按 packet_id 存储。
///
  /// 分片长度不保证一致，因此按 ID 保存，
  /// 帧完成后再按 packet_id 顺序拼接。
  /// 这样可避免按偏移写入时因尾包更短而破坏帧数据。
  final Map<int, Uint8List> packets = {};

  /// 当前已接收字节数（所有分片长度之和）。
  int bytesReceived = 0;

  /// 当前缓存是否已完成。
  bool isComplete = false;

  /// 按 packet_id 顺序拼接全部分片，并裁剪到 [frameSize]。
  Uint8List assemble() {
    final sortedIds = packets.keys.toList()..sort();
    final out = Uint8List(frameSize);
    var pos = 0;
    for (final id in sortedIds) {
      final frag = packets[id]!;
      final remaining = frameSize - pos;
      if (remaining <= 0) break;
      final take = frag.length <= remaining ? frag.length : remaining;
      out.setRange(pos, pos + take, frag);
      pos += take;
    }
    return out;
  }
}

/// 从 UDP 包分片中重组 HEVC 帧。
class FrameReassembler {
  /// 创建 [FrameReassembler]。
  ///
  /// [maxFrames] 限制并发缓存帧数，避免内存泄漏。
  /// [timeout] 定义等待缺失分片的最长时间。
  FrameReassembler({
    this.maxFrames = maxCachedFrames,
    this.timeout = frameReassemblyTimeout,
  });

  /// 最多同时缓存的帧数。
  final int maxFrames;

  /// 未完成帧的重组超时时间。
  final Duration timeout;

  /// 帧 ID 到重组缓存的映射。
  final Map<int, _FrameBuffer> _buffers = {};

  /// 已完成帧输出流控制器。
  final _frameController = StreamController<VideoFrame>.broadcast();

  /// 完整重组后的帧流。
  Stream<VideoFrame> get frameStream => _frameController.stream;

  /// 当前仍在重组中的帧数。
  int get pendingFrameCount => _buffers.length;

  /// 因超时或缓存溢出丢弃的总帧数。
  int framesDropped = 0;

  /// 成功重组的总帧数。
  int framesCompleted = 0;

  /// 已完成且携带 HEVC 参数集（VPS/SPS/PPS）的帧数。
///
  /// 如果 [framesCompleted] 持续增长而该值仍为 0，
  /// 说明携带参数集的关键帧一直没有完整重组，
  /// 这通常会导致解码器已连接但没有画面。
  int framesWithParamSet = 0;

  /// 单帧内已见到的最大分片数（无论该帧是否完成）。
///
  /// 关键帧通常比分间帧包含更多分片；
  /// 该值用于判断大关键帧的分片是否真正到达。
  int maxFragmentsSeen = 0;

  /// 已见到的最大声明 frame_size，单位字节。
  int maxFrameSizeSeen = 0;

  /// 清理过期缓存的周期性定时器。
  Timer? _cleanupTimer;

  /// 启动后台过期帧清理。
  void start() {
    _cleanupTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _cleanupStaleBuffers(),
    );
  }

  /// 停止后台清理并释放资源。
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _buffers.clear();
    _frameController.close();
  }

  /// 处理单个 UDP 包。
///
  /// [packet] 包含 8 字节头部和载荷。
  /// 如果包被接受，返回 true。
  bool processPacket(Uint8List packet) {
    if (packet.length < udpPacketHeaderSize) {
      return false;
    }

    // 包头字段使用大端序（网络字节序）。若按小端序读取，
    // frame_size 会膨胀超过 4 MB 上限并导致所有包被丢弃，
    // packet_id 也会被打乱，进而破坏分片顺序。
    final frameId = readUint16BE(packet, udpFrameIdOffset);
    final packetId = readUint16BE(packet, udpPacketIdOffset);
    final frameSize = readUint32BE(packet, udpFrameSizeOffset);

    if (frameSize > maxFrameSizeBytes || frameSize <= 0) {
      return false;
    }

    // 复制载荷而不是使用 sublistView：视图会共享 datagram 的底层缓冲区，
    // 套接字层可能在下一个包到来时复用该缓冲区，
    // 从而污染已经保存的分片并造成花屏或 “Could not find ref with POC”。
    final payload = packet.sublist(udpPacketHeaderSize);

    _acceptFragment(frameId, packetId, frameSize, payload);
    return true;
  }

  void _acceptFragment(
    int frameId,
    int packetId,
    int frameSize,
    Uint8List payload,
  ) {
    _cleanupStaleBuffers();

    // 缓存已满且当前是新帧时，丢弃最旧帧。
    if (!_buffers.containsKey(frameId) && _buffers.length >= maxFrames) {
      final oldestId = _buffers.keys.reduce((a, b) => a < b ? a : b);
      _dropFrame(oldestId, reason: 'capacity');
    }

    final buffer = _buffers.putIfAbsent(
      frameId,
      () => _FrameBuffer(
        frameId: frameId,
        frameSize: frameSize,
        firstPacketTime: DateTime.now(),
      ),
    );

    // 防御性处理：同一帧的 frameSize 不一致时丢弃该帧。
    if (buffer.frameSize != frameSize) {
      _dropFrame(frameId, reason: 'size_mismatch');
      return;
    }

    // 按 packet_id 存储分片，最终按 packet_id 顺序拼接。
    // 这里不做偏移计算，因此较短的尾包不会破坏整帧。
    if (!buffer.packets.containsKey(packetId)) {
      buffer.packets[packetId] = payload;
      buffer.bytesReceived += payload.length;
    }

    // 诊断用：记录见过的最大帧和最多分片帧。
    if (frameSize > maxFrameSizeSeen) maxFrameSizeSeen = frameSize;
    if (buffer.packets.length > maxFragmentsSeen) {
      maxFragmentsSeen = buffer.packets.length;
    }

    // 字节数达到声明帧长时认为该帧完成。
    if (buffer.bytesReceived >= frameSize) {
      _finalizeFrame(frameId);
    }
  }

  void _finalizeFrame(int frameId) {
    final buffer = _buffers[frameId];
    if (buffer == null || buffer.isComplete) return;

    buffer.isComplete = true;
    framesCompleted++;

    final now = DateTime.now();
    final assembled = buffer.assemble();
    if (hevcHasParameterSet(assembled)) {
      framesWithParamSet++;
    }
    final frame = VideoFrame(
      frameId: frameId,
      packetCount: buffer.packets.length,
      annexbData: ensureAnnexbPrefix(assembled),
      timestamp: now,
      reassemblyTime: now.difference(buffer.firstPacketTime),
    );

    _buffers.remove(frameId);
    _frameController.add(frame);
  }

  void _cleanupStaleBuffers() {
    final now = DateTime.now();
    final staleIds = _buffers.entries
        .where((e) => now.difference(e.value.firstPacketTime) > timeout)
        .map((e) => e.key)
        .toList();

    for (final id in staleIds) {
      _dropFrame(id, reason: 'timeout');
    }
  }

  void _dropFrame(int frameId, {required String reason}) {
    final buffer = _buffers.remove(frameId);
    if (buffer != null) {
      framesDropped++;
    }
  }
}
