/// 协议解析用二进制数据读取工具。
///
/// 默认读取小端序数值，同时提供 HEVC AnnexB 起始码和参数集检测辅助函数。
library;

import 'dart:typed_data';

// ============================================================
// AnnexB 起始码常量
// ============================================================

const int _annexbByteZero = 0x00;
const int _annexbByteOne = 0x01;

const int _annexbLongPrefixLength = 4;
const int _annexbShortPrefixLength = 3;

const List<int> _annexbLongPrefix = [
  _annexbByteZero,
  _annexbByteZero,
  _annexbByteZero,
  _annexbByteOne,
];

const List<int> _annexbShortPrefix = [
  _annexbByteZero,
  _annexbByteZero,
  _annexbByteOne,
];

// ============================================================
// 小端序整数读取
// ============================================================

/// 校验 [offset] 非负，且 [requiredBytes] 字节不会越过 [data] 边界。
void _checkBounds(Uint8List data, int offset, int requiredBytes, String name) {
  if (offset < 0) {
    throw RangeError('$name: offset $offset is negative');
  }
  if (offset + requiredBytes > data.length) {
    throw RangeError(
      '$name: offset $offset+$requiredBytes out of bounds '
      '(length ${data.length})',
    );
  }
}

/// 从 [data] 的 [offset] 位置读取一个 uint8。
int readUint8(Uint8List data, int offset) {
  _checkBounds(data, offset, 1, 'readUint8');
  return data[offset];
}

/// 从 [data] 的 [offset] 位置读取一个小端序 uint16。
int readUint16(Uint8List data, int offset) {
  _checkBounds(data, offset, 2, 'readUint16');
  return data[offset] | (data[offset + 1] << 8);
}

/// 从 [data] 的 [offset] 位置读取一个小端序 uint32。
int readUint32(Uint8List data, int offset) {
  _checkBounds(data, offset, 4, 'readUint32');
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}

/// 从 [data] 的 [offset] 位置读取一个小端序 float32。
///
/// 使用 [ByteData] 完成 IEEE 754 转换。
double readFloat32(Uint8List data, int offset) {
  _checkBounds(data, offset, 4, 'readFloat32');
  final byteData = ByteData.sublistView(data, offset, offset + 4);
  return byteData.getFloat32(0, Endian.little);
}

// ============================================================
// 大端序整数读取（网络字节序）
// ============================================================

/// 从 [data] 的 [offset] 位置读取一个大端序 uint16。
int readUint16BE(Uint8List data, int offset) {
  _checkBounds(data, offset, 2, 'readUint16BE');
  return (data[offset] << 8) | data[offset + 1];
}

/// 从 [data] 的 [offset] 位置读取一个大端序 uint32。
int readUint32BE(Uint8List data, int offset) {
  _checkBounds(data, offset, 4, 'readUint32BE');
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

// ============================================================
// AnnexB 起始码检测
// ============================================================

/// 检查 [data] 从 [offset] 开始是否为 4 字节 AnnexB 起始码。
bool hasAnnexbStartCode(Uint8List data, int offset) {
  if (offset + _annexbLongPrefixLength > data.length) return false;
  for (var i = 0; i < _annexbLongPrefixLength; i++) {
    if (data[offset + i] != _annexbLongPrefix[i]) return false;
  }
  return true;
}

/// 检查 [data] 从 [offset] 开始是否为 3 字节短 AnnexB 起始码。
bool hasAnnexbStartCodeShort(Uint8List data, int offset) {
  if (offset + _annexbShortPrefixLength > data.length) return false;
  for (var i = 0; i < _annexbShortPrefixLength; i++) {
    if (data[offset + i] != _annexbShortPrefix[i]) return false;
  }
  return true;
}

/// 检查 [data] 从 [offset] 开始是否为任意 AnnexB 起始码变体。
bool hasAnyAnnexbStartCode(Uint8List data, int offset) {
  return hasAnnexbStartCode(data, offset) ||
      hasAnnexbStartCodeShort(data, offset);
}

// ============================================================
// 位字段提取
// ============================================================

/// 从 [value] 中提取 [startBit]（含）到 [endBit]（不含）之间的位字段。
///
/// 示例：`extractBits(0b101100, 1, 4) == 0b110`。
int extractBits(int value, int startBit, int endBit) {
  if (startBit < 0) {
    throw ArgumentError('startBit must be non-negative, got $startBit');
  }
  if (endBit <= startBit) {
    throw ArgumentError(
      'endBit ($endBit) must be greater than startBit ($startBit)',
    );
  }
  final bitWidth = endBit - startBit;
  if (bitWidth > 63) {
    throw ArgumentError(
      'Bit width $bitWidth exceeds maximum safe width of 63',
    );
  }
  final mask = (1 << bitWidth) - 1;
  return (value >> startBit) & mask;
}

// ============================================================
// AnnexB 前缀辅助函数
// ============================================================

/// 创建包含 4 字节 AnnexB 起始码的 [Uint8List]。
Uint8List createAnnexbStartCode() => Uint8List.fromList(_annexbLongPrefix);

/// 如果 [naluData] 尚未包含 AnnexB 起始码，则在前面补上。
Uint8List ensureAnnexbPrefix(Uint8List naluData) {
  if (hasAnyAnnexbStartCode(naluData, 0)) return naluData;
  final result = Uint8List(naluData.length + _annexbLongPrefixLength)
    ..setAll(0, createAnnexbStartCode())
    ..setAll(_annexbLongPrefixLength, naluData);
  return result;
}

// ============================================================
// HEVC 参数集检测
// ============================================================

/// HEVC 参数集对应的 `nal_unit_type` 值。
const int _hevcNalVps = 32;
const int _hevcNalSps = 33;
const int _hevcNalPps = 34;

/// 当 [data] 包含 VPS、SPS 或 PPS NAL 单元时返回 true。
///
/// 遍历 3 字节或 4 字节 AnnexB 起始码，并读取每个起始码之后的 6 位
/// `nal_unit_type`。携带这些参数集之一的帧就是解码器开始渲染前必须看到的
/// 关键帧。
bool hevcHasParameterSet(Uint8List data) {
  final n = data.length;
  var i = 0;
  while (i + 3 < n) {
    final isLong =
        data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 1;
    final isShort = data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1;
    if (isLong || isShort) {
      final hdr = i + (isLong ? 4 : 3);
      if (hdr < n) {
        final nalType = (data[hdr] >> 1) & 0x3F;
        if (nalType == _hevcNalVps ||
            nalType == _hevcNalSps ||
            nalType == _hevcNalPps) {
          return true;
        }
      }
      i = hdr;
    } else {
      i++;
    }
  }
  return false;
}
