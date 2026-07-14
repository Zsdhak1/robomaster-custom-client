/// 将原始 `CustomByteBlock.data` 包转换为解码流中真正需要的 H.264 AnnexB 字节。
///
/// 抓包显示，0x0310 流的每个包都在载荷前带有内嵌 protobuf 风格长度前缀：
/// `0x0A <varint 长度> <载荷> [0x00 padding]`。这里要恢复精确的 `<载荷>`，
/// 去掉前缀和填充，连续拼接后得到干净的 AnnexB 字节流。
library;

import 'dart:typed_data';

/// 单个包切片结果：输出字节以及前缀解析信息。
class SliceResult {
  /// 创建 [SliceResult]。
  const SliceResult({
    required this.bytes,
    required this.prefixBytes,
    required this.declaredLength,
    required this.prefixDetected,
  });

  /// 要继续向下游转发的 H.264 字节，可能为空。
  final Uint8List bytes;

  /// 已消费的前导前缀字节数；没有前缀时为 0。
  final int prefixBytes;

  /// varint 前缀声明的载荷长度；未检测到前缀时为 -1。
  final int declaredLength;

  /// 包开头是否识别到 `0x0A <varint>` 前缀。
  final bool prefixDetected;
}

/// 去掉内嵌的 `0x0A <varint 长度>` 前缀，并返回声明长度内的载荷字节。
///
/// 如果包不是以 `0x0A` 开头，或 varint 超出缓冲区，则安全降级为返回整个包，
/// 并将 [SliceResult.prefixDetected] 置为 false，避免在格式异常时丢数据。
SliceResult stripVarintPrefix(Uint8List data) {
  // 至少需要 0x0A tag 和一个 varint 字节。
  if (data.length < 2 || data[0] != 0x0A) {
    return SliceResult(
      bytes: data,
      prefixBytes: 0,
      declaredLength: -1,
      prefixDetected: false,
    );
  }
  // 从索引 1 开始解码 base-128 varint。
  var value = 0;
  var shift = 0;
  var i = 1;
  while (i < data.length) {
    final b = data[i];
    value |= (b & 0x7F) << shift;
    i++;
    if (b & 0x80 == 0) break;
    shift += 7;
    if (shift > 28) {
      // 长度 varint 不可信，直接原样透传。
      return SliceResult(
        bytes: data,
        prefixBytes: 0,
        declaredLength: -1,
        prefixDetected: false,
      );
    }
  }
  final payloadStart = i;
  final available = data.length - payloadStart;
  // 将声明长度限制在实际收到的字节范围内。
  final take = value <= available ? value : available;
  return SliceResult(
    bytes: Uint8List.sublistView(data, payloadStart, payloadStart + take),
    prefixBytes: payloadStart,
    declaredLength: value,
    prefixDetected: true,
  );
}

/// 跳过 [headerBytes] 后最多取 [payloadBytes] 字节，用于手动固定切片模式。
SliceResult sliceFixed(Uint8List data, int headerBytes, int payloadBytes) {
  final start = headerBytes < data.length ? headerBytes : data.length;
  final end = (start + payloadBytes) < data.length
      ? (start + payloadBytes)
      : data.length;
  return SliceResult(
    bytes: Uint8List.sublistView(data, start, end),
    prefixBytes: start,
    declaredLength: payloadBytes,
    prefixDetected: false,
  );
}
