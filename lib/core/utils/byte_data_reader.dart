/// Binary data reading utilities for protocol parsing.
///
/// All methods read in little-endian order.
/// HEVC NALU prefix detection helpers included.
library;

import 'dart:typed_data';

// ============================================================
// AnnexB start code constants
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
// Little-endian integer readers
// ============================================================

/// Validates that [offset] is non-negative and [requiredBytes] fit in [data].
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

/// Reads a little-endian uint8 from [data] at [offset].
int readUint8(Uint8List data, int offset) {
  _checkBounds(data, offset, 1, 'readUint8');
  return data[offset];
}

/// Reads a little-endian uint16 from [data] at [offset].
int readUint16(Uint8List data, int offset) {
  _checkBounds(data, offset, 2, 'readUint16');
  return data[offset] | (data[offset + 1] << 8);
}

/// Reads a little-endian uint32 from [data] at [offset].
int readUint32(Uint8List data, int offset) {
  _checkBounds(data, offset, 4, 'readUint32');
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}

/// Reads a little-endian float32 from [data] at [offset].
///
/// Uses ByteData for IEEE 754 conversion.
double readFloat32(Uint8List data, int offset) {
  _checkBounds(data, offset, 4, 'readFloat32');
  final byteData = ByteData.sublistView(data, offset, offset + 4);
  return byteData.getFloat32(0, Endian.little);
}

// ============================================================
// Big-endian integer readers (network byte order)
// ============================================================

/// Reads a big-endian uint16 from [data] at [offset].
int readUint16BE(Uint8List data, int offset) {
  _checkBounds(data, offset, 2, 'readUint16BE');
  return (data[offset] << 8) | data[offset + 1];
}

/// Reads a big-endian uint32 from [data] at [offset].
int readUint32BE(Uint8List data, int offset) {
  _checkBounds(data, offset, 4, 'readUint32BE');
  return (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

// ============================================================
// AnnexB start code detection
// ============================================================

/// Checks if [data] at [offset] starts with AnnexB start code (4 bytes).
bool hasAnnexbStartCode(Uint8List data, int offset) {
  if (offset + _annexbLongPrefixLength > data.length) return false;
  for (var i = 0; i < _annexbLongPrefixLength; i++) {
    if (data[offset + i] != _annexbLongPrefix[i]) return false;
  }
  return true;
}

/// Checks if [data] at [offset] starts with short AnnexB start code (3 bytes).
bool hasAnnexbStartCodeShort(Uint8List data, int offset) {
  if (offset + _annexbShortPrefixLength > data.length) return false;
  for (var i = 0; i < _annexbShortPrefixLength; i++) {
    if (data[offset + i] != _annexbShortPrefix[i]) return false;
  }
  return true;
}

/// Checks if [data] at [offset] starts with any AnnexB start code variant.
bool hasAnyAnnexbStartCode(Uint8List data, int offset) {
  return hasAnnexbStartCode(data, offset) ||
      hasAnnexbStartCodeShort(data, offset);
}

// ============================================================
// Bit extraction
// ============================================================

/// Extracts bit field from [value] between [startBit] (inclusive)
/// and [endBit] (exclusive).
///
/// Example: extractBits(0b101100, 1, 4) => 0b110 = 6
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
// AnnexB prefix helpers
// ============================================================

/// Creates a Uint8List containing the 4-byte AnnexB start code.
Uint8List createAnnexbStartCode() => Uint8List.fromList(_annexbLongPrefix);

/// Prepends AnnexB start code to [naluData] if not already present.
Uint8List ensureAnnexbPrefix(Uint8List naluData) {
  if (hasAnyAnnexbStartCode(naluData, 0)) return naluData;
  final result = Uint8List(naluData.length + _annexbLongPrefixLength)
    ..setAll(0, createAnnexbStartCode())
    ..setAll(_annexbLongPrefixLength, naluData);
  return result;
}

// ============================================================
// HEVC parameter-set detection
// ============================================================

/// HEVC nal_unit_type values for parameter sets.
const int _hevcNalVps = 32;
const int _hevcNalSps = 33;
const int _hevcNalPps = 34;

/// Returns true if [data] contains a VPS, SPS or PPS NAL unit.
///
/// Walks AnnexB start codes (3- or 4-byte) and reads the 6-bit
/// nal_unit_type from the byte after each start code. A frame carrying any
/// of these parameter sets is the keyframe the decoder must see before it
/// can render anything.
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
