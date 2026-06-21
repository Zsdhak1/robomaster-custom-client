/// Pure functions that turn one raw `CustomByteBlock.data` packet into the
/// H.264 Annex-B bytes that belong in the decoded stream.
///
/// Captured 0x0310 streams show each packet's payload is wrapped in an in-band
/// protobuf-style length prefix: `0x0A <varint length> <payload> [0x00 pad]`.
/// The job here is to recover exactly `<payload>` (no prefix, no padding) so
/// concatenating successive packets yields a clean Annex-B byte stream.
library;

import 'dart:typed_data';

/// Result of slicing one packet: the bytes to emit plus how the prefix parsed.
class SliceResult {
  /// Creates a [SliceResult].
  const SliceResult({
    required this.bytes,
    required this.prefixBytes,
    required this.declaredLength,
    required this.prefixDetected,
  });

  /// The H.264 bytes to forward downstream (may be empty).
  final Uint8List bytes;

  /// Number of leading prefix bytes consumed (0 if none).
  final int prefixBytes;

  /// Length declared by the varint prefix, or -1 if no prefix was detected.
  final int declaredLength;

  /// Whether a `0x0A <varint>` prefix was recognised at the packet start.
  final bool prefixDetected;
}

/// Strips an in-band `0x0A <varint length>` prefix and returns the declared
/// payload bytes (dropping any trailing padding past the declared length).
///
/// If the packet does not start with `0x0A`, or the varint runs past the
/// buffer, the whole packet is returned with [SliceResult.prefixDetected]
/// false — a safe fallback that never drops data when the format is unexpected.
SliceResult stripVarintPrefix(Uint8List data) {
  // Need at least the 0x0A tag + one varint byte.
  if (data.length < 2 || data[0] != 0x0A) {
    return SliceResult(
      bytes: data,
      prefixBytes: 0,
      declaredLength: -1,
      prefixDetected: false,
    );
  }
  // Decode the base-128 varint starting at index 1.
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
      // Implausible length varint — bail to verbatim.
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
  // Clamp the declared length to what actually arrived.
  final take = value <= available ? value : available;
  return SliceResult(
    bytes: Uint8List.sublistView(data, payloadStart, payloadStart + take),
    prefixBytes: payloadStart,
    declaredLength: value,
    prefixDetected: true,
  );
}

/// Skips [headerBytes] then takes up to [payloadBytes] bytes (manual mode).
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
