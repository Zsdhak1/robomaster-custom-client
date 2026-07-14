/// 从 UDP 流重组出的 HEVC 视频帧。
library;

import 'dart:typed_data';

/// 表示一个已经完成重组的 HEVC AnnexB 帧。
class VideoFrame {
  /// 使用已校验参数创建 [VideoFrame]。
  VideoFrame({
    required this.frameId,
    required this.packetCount,
    required this.annexbData,
    required this.timestamp,
    required this.reassemblyTime,
  });

  /// 帧 ID，同一帧的所有分片共享该值。
  final int frameId;

  /// 组成该帧的 UDP 分片总数。
  final int packetCount;

  /// 带 AnnexB 起始码前缀的完整 HEVC 数据。
  final Uint8List annexbData;

  /// 重组完成时的时间戳。
  final DateTime timestamp;

  /// 从收到首个分片到完成重组的耗时。
  final Duration reassemblyTime;
}
