/// H.264 (AVC) parameter-set detection for the custom video line (0x0310).
///
/// Deliberately separate from the HEVC detector in `byte_data_reader.dart`:
/// the two codecs encode `nal_unit_type` differently, so mixing them would
/// let one line's keyframe gate misfire on the other line's stream.
///
/// HEVC: `nal_unit_type = (firstByte >> 1) & 0x3F`, params VPS=32/SPS=33/PPS=34.
/// H.264: `nal_unit_type = firstByte & 0x1F`, params SPS=7/PPS=8 (no VPS).
library;

import 'dart:typed_data';

/// H.264 nal_unit_type for a Sequence Parameter Set.
const int _h264NalSps = 7;

/// H.264 nal_unit_type for a Picture Parameter Set.
const int _h264NalPps = 8;

/// Returns true if [data] contains an H.264 SPS or PPS NAL unit.
///
/// Walks AnnexB start codes (3- or 4-byte) and reads the 5-bit nal_unit_type
/// from the byte after each start code. A frame carrying SPS/PPS is the
/// keyframe the decoder must see before it can render anything.
///
/// HEVC parameter sets do NOT match: HEVC VPS/SPS/PPS (32/33/34) reduce under
/// `& 0x1F` to 0/1/2, never 7 or 8, so an HEVC stream never trips this gate.
bool h264HasParameterSet(Uint8List data) {
  final n = data.length;
  var i = 0;
  while (i + 3 < n) {
    final isLong =
        data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 0 && data[i + 3] == 1;
    final isShort = data[i] == 0 && data[i + 1] == 0 && data[i + 2] == 1;
    if (isLong || isShort) {
      final hdr = i + (isLong ? 4 : 3);
      if (hdr < n) {
        final nalType = data[hdr] & 0x1F;
        if (nalType == _h264NalSps || nalType == _h264NalPps) {
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
