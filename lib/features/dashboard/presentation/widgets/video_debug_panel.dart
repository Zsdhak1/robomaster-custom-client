/// Debug telemetry panel for the video stream pipeline.
///
/// Displays real-time UDP reception stats, frame reassembly health,
/// TCP bridge status and the latest frame header — all updated every
/// second so you can see exactly where the pipeline is alive or stuck.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/video/video_frame.dart';
import '../../../../services/video_stream_service.dart';
import '../../logic/stream_providers.dart';

/// Embeddable debug content (no floating chrome) for the side panel.
///
/// Renders per-stage video-pipeline stats as a plain column that can be
/// dropped into the shared `VideoSidePanel`. Refreshes every 500 ms so the
/// counters feel live.
class VideoDebugContent extends StatefulWidget {
  /// Creates a [VideoDebugContent].
  const VideoDebugContent({super.key});

  @override
  State<VideoDebugContent> createState() => _VideoDebugContentState();
}

class _VideoDebugContentState extends State<VideoDebugContent> {
  late final Timer _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final service = ref.watch(videoStreamServiceProvider);
        final latestFrame = ref.watch(videoFrameProvider).valueOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(title: 'UDP 接收', color: Colors.cyan),
            _UdpStats(service: service),
            context.sizedBox(h: 12),
            const _SectionTitle(title: '原始包诊断', color: Colors.redAccent),
            _RawPacketDiag(service: service),
            context.sizedBox(h: 12),
            const _SectionTitle(title: '帧重组', color: Colors.orange),
            _FrameStats(service: service),
            context.sizedBox(h: 12),
            const _SectionTitle(title: 'TCP 桥', color: Colors.green),
            _TcpStats(service: service),
            context.sizedBox(h: 12),
            const _SectionTitle(title: '最新帧', color: Colors.purple),
            _LatestFrame(frame: latestFrame),
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 4, height: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _UdpStats extends StatelessWidget {
  const _UdpStats({required this.service});

  final VideoStreamService service;

  @override
  Widget build(BuildContext context) {
    return _TwoColumnGrid(children: [
      _StatItem(label: '监听状态', value: service.isListening ? '是' : '否'),
      _StatItem(label: '监听端口', value: '${service.isListening ? 3334 : "—"}'),
      _StatItem(label: '收包数', value: '${service.packetsReceived}'),
      _StatItem(label: '解析丢包', value: '${service.packetsDropped}'),
      _StatItem(
        label: '接收缓冲(8MB)',
        value: service.receiveBufferEnlarged ? '已扩大' : '默认',
      ),
    ]);
  }
}

/// Raw first-packet diagnosis: header hex + frame_size parsed both ways.
///
/// The reassembler reads frame_size little-endian and rejects any frame
/// over 4 MB. If the source uses network (big-endian) order, the LE value
/// blows past 4 MB and every packet is dropped — this panel makes that
/// immediately visible by showing both interpretations side by side.
class _RawPacketDiag extends StatelessWidget {
  const _RawPacketDiag({required this.service});

  final VideoStreamService service;

  static const int _maxFrameSize = 4 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final bytes = service.firstPacketBytes;
    if (bytes == null) {
      return const Text(
        '尚未捕获到任何包',
        style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
      );
    }
    final le = service.firstFrameSizeLittleEndian;
    final be = service.firstFrameSizeBigEndian;
    final leOk = le != null && le > 0 && le <= _maxFrameSize;
    final beOk = be != null && be > 0 && be <= _maxFrameSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatItem(label: '首包长度', value: '${service.firstPacketLength} 字节'),
        const SizedBox(height: 4),
        Text(
          '头部 hex: ${_hexJoin(bytes)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        _frameSizeRow('小端解析 (当前)', le, leOk),
        _frameSizeRow('大端解析 (网络序)', be, beOk),
        const SizedBox(height: 4),
        Text(
          _verdict(leOk, beOk),
          style: TextStyle(
            color: leOk ? Colors.green : Colors.redAccent,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _frameSizeRow(String label, int? value, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '$label: ${value ?? "—"}  ${ok ? "✓ 合理" : "✗ 越界"}',
        style: TextStyle(
          color: ok ? Colors.green : Colors.orange,
          fontSize: 11,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  String _verdict(bool leOk, bool beOk) {
    if (leOk) return '判定: 小端正确，问题不在字节序';
    if (beOk) return '判定: 应改用大端(网络序)解析 frame_size！';
    return '判定: 两种字节序都越界，包格式可能与预期不符';
  }

  String _hexJoin(Uint8List b) {
    return b.map((x) => x.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}

class _FrameStats extends StatelessWidget {
  const _FrameStats({required this.service});

  final VideoStreamService service;

  @override
  Widget build(BuildContext context) {
    return _TwoColumnGrid(children: [
      _StatItem(label: '重组成功', value: '${service.framesCompleted}'),
      _StatItem(label: '重组丢弃', value: '${service.framesDropped}'),
      _StatItem(label: '等待中', value: '${service.pendingFrameCount}'),
      _StatItem(
        label: '成功率',
        value: service.framesCompleted + service.framesDropped > 0
            ? '${((service.framesCompleted /
                        (service.framesCompleted + service.framesDropped)) *
                    100)
                .toStringAsFixed(1)}%'
            : '—',
      ),
      _StatItem(
        label: '★含参数集帧',
        value: '${service.framesWithParamSet}',
      ),
      _StatItem(label: '最大分片数', value: '${service.maxFragmentsSeen}'),
      _StatItem(
        label: '最大帧',
        value: _formatBytes(service.maxFrameSizeSeen),
      ),
    ]);
  }
}

class _TcpStats extends StatelessWidget {
  const _TcpStats({required this.service});

  final VideoStreamService service;

  @override
  Widget build(BuildContext context) {
    return _TwoColumnGrid(children: [
      _StatItem(
        label: '桥状态',
        value: service.streamUrl != null ? '运行中' : '未启动',
      ),
      _StatItem(label: '桥端口', value: service.streamUrl ?? '—'),
      _StatItem(label: '解码器连接', value: '${service.decoderClients}'),
      _StatItem(
        label: '★关键帧门控',
        value: service.bridgeStarted ? '已开启' : '等待参数集',
      ),
      _StatItem(label: '门控缓存', value: '${service.bridgePending}'),
      _StatItem(label: '转发帧数', value: '${service.tcpFramesForwarded}'),
      _StatItem(
        label: '转发字节',
        value: _formatBytes(service.tcpBytesForwarded),
      ),
    ]);
  }
}

class _LatestFrame extends StatelessWidget {
  const _LatestFrame({this.frame});

  final VideoFrame? frame;

  @override
  Widget build(BuildContext context) {
    if (frame == null) {
      return const Text(
        '暂无帧数据',
        style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TwoColumnGrid(children: [
          _StatItem(label: '帧 ID', value: '${frame!.frameId}'),
          _StatItem(label: '分片数', value: '${frame!.packetCount}'),
          _StatItem(
            label: '帧大小',
            value: _formatBytes(frame!.annexbData.length),
          ),
          _StatItem(
            label: '重组耗时',
            value: '${frame!.reassemblyTime.inMilliseconds} ms',
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          '前 32 字节 Hex:',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _hexPrefix(frame!.annexbData, 32),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: children,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(2)} MB';
}

String _hexPrefix(Uint8List data, int maxLen) {
  final len = data.length > maxLen ? maxLen : data.length;
  final parts = <String>[];
  for (var i = 0; i < len; i++) {
    parts.add(data[i].toRadixString(16).padLeft(2, '0'));
  }
  return parts.join(' ');
}
