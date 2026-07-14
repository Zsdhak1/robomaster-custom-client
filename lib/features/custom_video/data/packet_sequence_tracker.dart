/// 跟踪每个 `CustomByteBlock` 包前置的 uint64 小端序序列号，用于测量丢包。
///
/// 机器人会在每个包前添加一个 8 字节 uint64 LE 计数器，每包递增 1。
/// 通过观察连续序列号之间的间隔，可以独立于 H.264 载荷统计链路丢失了多少包。
library;

import 'dart:typed_data';

/// 观察一个包序列号后的结果。
enum SeqObservation {
  /// 重置后见到的第一个包，作为基准，不计为丢失。
  first,

  /// 序列号正好递增 1，没有丢包。
  inOrder,

  /// 序列号递增超过 1，中间间隔计为丢失包。
  gap,

  /// 序列号倒退或重复（乱序 / 重启），不计为丢包。
  regressed,
}

/// 用于丢包报告的序列号累计统计器。
class PacketSequenceTracker {
  /// 最近一次观察到的序列号；首包之前为 null。
  int? _lastSeq;

  /// 自 [reset] 后观察到的第一个序列号，用作丢包率基准。
  int? _firstSeq;

  /// 自 [reset] 后观察到的总包数。
  int packetsSeen = 0;

  /// 自 [reset] 后从序列号间隔推断出的丢失包数。
  int packetsLost = 0;

  /// 自 [reset] 后出现的乱序或倒退序列号次数。
  int regressions = 0;

  /// 最近观察到的序列号，用于显示。
  int get lastSeq => _lastSeq ?? 0;

  /// 是否已经观察到至少一个包。
  bool get hasData => _lastSeq != null;

  /// 观察范围内的预期包数：最后一个 - 第一个 + 1。
  int get expectedPackets {
    final f = _firstSeq;
    final l = _lastSeq;
    if (f == null || l == null || l < f) return packetsSeen;
    return l - f + 1;
  }

  /// 观察范围内的丢包率，取值范围为 `[0, 1]`：丢失包数 / 预期包数。
  double get lossRate {
    final expected = expectedPackets;
    if (expected <= 0) return 0;
    return packetsLost / expected;
  }

  /// 重置所有计数器，通常在流启动或停止时调用。
  void reset() {
    _lastSeq = null;
    _firstSeq = null;
    packetsSeen = 0;
    packetsLost = 0;
    regressions = 0;
  }

  /// 从 [data] 前 8 字节读取 uint64 LE 序列号并更新丢包计数器。
  ///
  /// 返回当前包与前一个包的关系。如果 [data] 短于 8 字节，则忽略该包并返回
  /// [SeqObservation.first]，且不修改状态。
  SeqObservation observe(Uint8List data) {
    if (data.length < 8) return SeqObservation.first;
    final seq = _readUint64Le(data);
    packetsSeen++;

    final prev = _lastSeq;
    if (prev == null) {
      _firstSeq = seq;
      _lastSeq = seq;
      return SeqObservation.first;
    }

    if (seq == prev + 1) {
      _lastSeq = seq;
      return SeqObservation.inOrder;
    }

    if (seq <= prev) {
      // 乱序、重复或计数器重启都不计为丢包。若看起来像重启（大幅倒退），
      // 则重置基准；否则保留高水位，避免后续正常包被误判为向前跳号。
      regressions++;
      if (prev - seq > 1024) {
        _firstSeq = seq;
        _lastSeq = seq;
        packetsLost = 0;
      }
      return SeqObservation.regressed;
    }

    // 向前跳号：seq > prev + 1，说明中间丢失了 seq - prev - 1 个包。
    packetsLost += seq - prev - 1;
    _lastSeq = seq;
    return SeqObservation.gap;
  }

  /// 从 [data] 前 8 字节读取一个小端序 uint64。
  ///
  /// Dart int 为 64 位有符号整数；超过 2^63 的序列号会变为负数。但在 50Hz 下，
  /// 需要运行数十亿年才会触发，因此这里可以忽略。
  static int _readUint64Le(Uint8List data) {
    final bd = ByteData.sublistView(data, 0, 8);
    return bd.getUint64(0, Endian.little);
  }
}
