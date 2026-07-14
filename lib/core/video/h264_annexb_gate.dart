/// 自定义图传链路（0x0310）使用的 H.264 / H.265 参数集检测。
///
/// 这里刻意独立于 `byte_data_reader.dart` 中的 HEVC 检测器：两个编码格式的
/// `nal_unit_type` 编码方式不同，混用会让某条链路的关键帧闸门误判另一条流。
///
/// HEVC：`nal_unit_type = (firstByte >> 1) & 0x3F`，参数集为 VPS=32/SPS=33/PPS=34。
/// H.264：`nal_unit_type = firstByte & 0x1F`，参数集为 SPS=7/PPS=8（无 VPS）。
library;

import 'dart:typed_data';

/// H.264 序列参数集的 `nal_unit_type`。
const int _h264NalSps = 7;

/// H.264 图像参数集的 `nal_unit_type`。
const int _h264NalPps = 8;

/// HEVC 视频参数集的 `nal_unit_type`。
const int _hevcNalVps = 32;

/// HEVC 序列参数集的 `nal_unit_type`。
const int _hevcNalSps = 33;

/// HEVC 图像参数集的 `nal_unit_type`。
const int _hevcNalPps = 34;

/// 当 [data] 包含 H.264 SPS 或 PPS NAL 单元时返回 true。
///
/// 遍历 3 字节或 4 字节 AnnexB 起始码，并读取每个起始码之后的 5 位
/// `nal_unit_type`。携带 SPS/PPS 的帧是解码器开始渲染前必须看到的关键帧。
///
/// HEVC 参数集不会误触发这里：HEVC VPS/SPS/PPS（32/33/34）经过 `& 0x1F`
/// 后变为 0/1/2，不会等于 7 或 8。
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

/// 当 [data] 包含 HEVC VPS、SPS 或 PPS NAL 单元时返回 true。
///
/// 遍历 3 字节或 4 字节 AnnexB 起始码，并读取每个起始码之后的 6 位
/// `nal_unit_type`。携带任一参数集的帧是解码器开始渲染前必须看到的关键帧。
///
/// 这是 `byte_data_reader.dart` 中 [hevcHasParameterSet] 的自定义链路版本；
/// 保留在这里可以让两条链路的 NAL 解析和闸门逻辑相互独立。
///
/// H.264 参数集不会误触发这里：H.264 SPS/PPS（7/8）经过 HEVC 掩码
/// `(>> 1) & 0x3F` 后变为 3/4，不会等于 32/33/34。
bool h265HasParameterSet(Uint8List data) {
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
