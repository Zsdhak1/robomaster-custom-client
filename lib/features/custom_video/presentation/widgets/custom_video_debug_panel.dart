/// Comprehensive debug panel for the custom H.264/H.265 video line (0x0310).
///
/// Surfaces the whole pipeline at a glance so a black screen can be triaged
/// fast: MQTT ingest -> keyframe gate -> MPEG-TS mux -> TCP bridge -> decoder.
/// Each section maps to one stage, with live throughput rates, the decoder's
/// negotiated resolution/codec/fps, and a rolling log of decoder events and
/// errors. Read top-to-bottom: the first section that looks wrong is where the
/// stream is stuck.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_video_providers.dart';

/// Full diagnostics panel shown beside the custom-video player.
// ============================================================
// Pipeline health — one-line verdict per stage
// ============================================================

/// Embeddable debug content (no Card chrome) for the shared side panel.
///
/// Renders the same pipeline sections as [CustomVideoDebugPanel] but as a plain
/// column so it can be dropped into `VideoSidePanel`'s developer section.
class CustomVideoDebugContent extends ConsumerWidget {
  /// Creates a [CustomVideoDebugContent].
  const CustomVideoDebugContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(customVideoStatsProvider).valueOrNull;
    final decoder = ref.watch(customVideoDecoderInfoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PipelineHealth(stats: stats, decoder: decoder),
        context.sizedBox(h: 8),
        _IngestSection(stats: stats),
        context.sizedBox(h: 8),
        _LossSection(stats: stats),
        context.sizedBox(h: 8),
        _KeyframeSection(stats: stats),
        context.sizedBox(h: 8),
        _BridgeSection(stats: stats),
        context.sizedBox(h: 8),
        _DecoderSection(decoder: decoder),
        context.sizedBox(h: 8),
        _DecoderLogSection(logs: decoder.logs),
      ],
    );
  }
}

/// A traffic-light summary of each pipeline stage.
class _PipelineHealth extends StatelessWidget {
  const _PipelineHealth({required this.stats, required this.decoder});

  final CustomVideoStats? stats;
  final CustomVideoDecoderInfo decoder;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final ingestOk = (s?.chunksReceived ?? 0) > 0;
    final gateOk = s?.gateOpen ?? false;
    final clientOk = (s?.decoderClients ?? 0) > 0;
    final pictureOk = decoder.hasResolution && decoder.playing;
    // A stalled feed: data was flowing but nothing arrived in >2s.
    final stale = (s?.millisSinceLastChunk ?? 0) > 2000 && ingestOk;

    return _Section(
      title: '流水线状态',
      children: [
        _HealthRow(
          label: 'MQTT 接收',
          ok: ingestOk && !stale,
          detail: !ingestOk
              ? '无数据（未连接/未订阅）'
              : stale
                  ? '已停顿 ${((s?.millisSinceLastChunk ?? 0) / 1000).toStringAsFixed(1)}s'
                  : '正常',
        ),
        _HealthRow(
          label: '关键帧门控',
          ok: gateOk,
          detail: gateOk
              ? '已打开'
              : s?.codec == CustomVideoCodec.h265
                  ? '等待 VPS/SPS/PPS…'
                  : '等待 SPS/PPS…',
        ),
        _HealthRow(
          label: '解码器连接',
          ok: clientOk,
          detail: clientOk ? '${s?.decoderClients} 个客户端' : '播放器未连接到桥',
        ),
        _HealthRow(
          label: '出图',
          ok: pictureOk,
          detail: decoder.lastError != null
              ? '解码错误'
              : pictureOk
                  ? '${decoder.width}x${decoder.height} 播放中'
                  : '等待画面…',
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.ok,
    required this.detail,
  });

  final String label;
  final bool ok;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetSym(v: 3),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: context.iconSize(14),
            color: ok ? Colors.green : Colors.orange,
          ),
          context.sizedBox(w: 6),
          SizedBox(
            width: context.sp(92),
            child: Text(label, style: context.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: context.textTheme.bodySmall!.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Ingest section — MQTT -> gate
// ============================================================

class _IngestSection extends StatelessWidget {
  const _IngestSection({required this.stats});

  final CustomVideoStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return _Section(
      title: 'MQTT 接收 (CustomByteBlock)',
      children: [
        _InfoRow(label: '收到 chunk', value: '${s?.chunksReceived ?? 0}'),
        _InfoRow(
          label: 'chunk 频率',
          value: '${(s?.chunksPerSec ?? 0).toStringAsFixed(1)} 包/s',
        ),
        _InfoRow(label: '收到字节', value: _formatBytes(s?.bytesReceived ?? 0)),
        _InfoRow(
          label: '入站码率',
          value: _formatRate(s?.bytesInPerSec ?? 0),
        ),
        _InfoRow(
          label: '距上一包',
          value: s?.millisSinceLastChunk == null
              ? '—'
              : '${s!.millisSinceLastChunk} ms',
        ),
        _InfoRow(
          label: '门控缓冲',
          value: _formatBytes(s?.gateBufferBytes ?? 0),
        ),
        _InfoRow(
          label: '关键帧门控',
          value: (s?.gateOpen ?? false) ? '已打开' : '等待中',
        ),
      ],
    );
  }
}

// ============================================================
// Loss section — packet sequence number & loss rate
// ============================================================

/// Shows the leading uint64 sequence number and the packet-loss rate derived
/// from gaps in it. A climbing loss rate points squarely at the robot→client
/// link (suspicion #1): the bytes never arrived, independent of how they are
/// later sliced or decoded.
class _LossSection extends StatelessWidget {
  const _LossSection({required this.stats});

  final CustomVideoStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final hasSeq = s?.hasSequence ?? false;
    final lossPct = ((s?.lossRate ?? 0) * 100).toStringAsFixed(2);
    return _Section(
      title: '丢包统计 (序列号)',
      children: [
        _InfoRow(
          label: '当前序列号',
          value: hasSeq ? '${s?.lastSequence}' : '未检测到包头',
        ),
        _InfoRow(label: '已收包数', value: '${s?.seqPacketsSeen ?? 0}'),
        _InfoRow(label: '丢包数', value: '${s?.packetsLost ?? 0}'),
        _InfoRow(
          label: '丢包率',
          value: hasSeq ? '$lossPct %' : '—',
        ),
        _InfoRow(label: '乱序/重复', value: '${s?.seqRegressions ?? 0}'),
      ],
    );
  }
}

// ============================================================
// Keyframe section — NAL-type tally over the post-slice stream
// ============================================================

/// Shows whether keyframes (IDR/SPS/PPS) actually arrive, the fast way to tell
/// "link never sends keyframes" from "keyframes arrive but packing corrupts
/// them". If non-IDR (type 1) climbs while IDR (type 5) and SPS (type 7) stay
/// at 0, the upstream link/encoder is not delivering keyframes. If IDR/SPS
/// climb but the picture still never appears, suspect the packing/slice mode.
class _KeyframeSection extends StatelessWidget {
  const _KeyframeSection({required this.stats});

  final CustomVideoStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final sinceKf = s?.millisSinceLastKeyframe;
    final isHevc = s?.codec == CustomVideoCodec.h265;
    return _Section(
      title: '关键帧诊断 (NAL 统计)',
      children: [
        if (isHevc) ...[
          _InfoRow(label: 'VPS 参数集 (type 32)', value: '${s?.vpsSeen ?? 0}'),
          _InfoRow(label: 'SPS 参数集 (type 33)', value: '${s?.spsSeen ?? 0}'),
          _InfoRow(
            label: 'IDR 关键帧 (types 19+20)',
            value: '${s?.keyframesSeen ?? 0}',
          ),
        ] else ...[
          _InfoRow(label: 'IDR 关键帧 (type 5)', value: '${s?.keyframesSeen ?? 0}'),
          _InfoRow(label: 'SPS 参数集 (type 7)', value: '${s?.spsSeen ?? 0}'),
        ],
        _InfoRow(
          label: '非关键帧 (type ${isHevc ? '1' : '1'})',
          value: '${s?.nonIdrSeen ?? 0}',
        ),
        _InfoRow(
          label: '距上一关键帧',
          value: sinceKf == null ? '从未收到' : '$sinceKf ms',
        ),
      ],
    );
  }
}

// ============================================================
// Bridge section — TCP bridge throughput
// ============================================================

class _BridgeSection extends StatelessWidget {
  const _BridgeSection({required this.stats});

  final CustomVideoStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return _Section(
      title: 'TCP 桥转发',
      children: [
        _InfoRow(label: '桥地址', value: s?.streamUrl ?? '—'),
        _InfoRow(
          label: '封装模式',
          value: (s?.tsWrap ?? false)
              ? 'MPEG-TS'
              : '原始 ${s?.codec == CustomVideoCodec.h265 ? "H.265" : "H.264"}',
        ),
        _InfoRow(label: '解码器连接数', value: '${s?.decoderClients ?? 0}'),
        _InfoRow(label: '待发关键帧前帧', value: '${s?.pendingFrames ?? 0}'),
        _InfoRow(label: '已转发帧数', value: '${s?.framesForwarded ?? 0}'),
        _InfoRow(
          label: '转发帧率',
          value: '${(s?.framesPerSec ?? 0).toStringAsFixed(1)} 帧/s',
        ),
        _InfoRow(label: '已转发字节', value: _formatBytes(s?.bytesForwarded ?? 0)),
        _InfoRow(label: '出站码率', value: _formatRate(s?.bytesOutPerSec ?? 0)),
      ],
    );
  }
}

// ============================================================
// Decoder section — what the player negotiated
// ============================================================

class _DecoderSection extends StatelessWidget {
  const _DecoderSection({required this.decoder});

  final CustomVideoDecoderInfo decoder;

  @override
  Widget build(BuildContext context) {
    final d = decoder;
    final res = d.hasResolution ? '${d.width}x${d.height}' : '—';
    final state = d.lastError != null
        ? '错误'
        : d.buffering
            ? '缓冲中'
            : d.playing
                ? '播放中'
                : '连接中…';
    return _Section(
      title: '解码器 (${d.backend ?? "未选择"})',
      children: [
        _InfoRow(label: '状态', value: state),
        _InfoRow(label: '打开次数', value: '第 ${d.attempt} 次'),
        _InfoRow(label: '分辨率', value: res),
        _InfoRow(label: '编解码', value: d.codec ?? '—'),
        _InfoRow(label: '像素格式', value: d.pixelFormat ?? '—'),
        _InfoRow(
          label: '解码帧率',
          value: d.decoderFps == null
              ? '—'
              : '${d.decoderFps!.toStringAsFixed(1)} fps',
        ),
        _InfoRow(
          label: '码流码率',
          value: d.bitRate == null ? '—' : _formatRate(d.bitRate! / 8),
        ),
        if (d.profile != null && d.profile! > 0)
          _InfoRow(label: 'Profile', value: '${d.profile}'),
        if (d.buffering && d.bufferingPercent != null)
          _InfoRow(
            label: '缓冲进度',
            value: '${d.bufferingPercent!.toStringAsFixed(0)}%',
          ),
        if (d.lastError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      d.lastError!,
                      style: context.textTheme.labelSmall!.copyWith(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// Decoder log — rolling event/error scrollback
// ============================================================

class _DecoderLogSection extends StatelessWidget {
  const _DecoderLogSection({required this.logs});

  final List<DecoderLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '解码器日志',
      children: [
        if (logs.isEmpty)
          Text(
            '暂无日志',
            style: context.textTheme.labelSmall!.copyWith(color: Colors.grey.shade600),
          )
        else
          // Newest first so the latest event is always visible without
          // scrolling; the panel itself is inside the parent ListView.
          ...logs.reversed.take(30).map((e) => _LogLine(entry: e)),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});

  final DecoderLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      DecoderLogLevel.info => Colors.grey.shade700,
      DecoderLogLevel.warn => Colors.orange,
      DecoderLogLevel.error => Colors.red,
    };
    final t = entry.time;
    final ts = '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ts,
            style: context.textTheme.labelSmall!.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              entry.message,
              style: context.textTheme.labelSmall!.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Shared building blocks
// ============================================================

/// A titled group of debug rows with a subtle divider.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: context.insetAll(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700),
          ),
          context.sizedBox(h: 6),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetSym(v: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall!.copyWith(color: Colors.grey.shade600),
          ),
          context.sizedBox(w: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w600),
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

String _formatRate(double bytesPerSec) {
  if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
  final kb = bytesPerSec / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB/s';
  return '${(kb / 1024).toStringAsFixed(2)} MB/s';
}
