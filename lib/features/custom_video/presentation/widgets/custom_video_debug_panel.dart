/// 自定义 H.264/H.265 视频链路（0x0310）的综合调试面板。
///
/// 以一屏视图展示整条流水线，便于快速定位黑屏：
/// MQTT 接入 -> 关键帧闸门 -> MPEG-TS 封装 -> TCP 桥接 -> 解码器。
/// 每个区段对应一个阶段，展示实时吞吐率、解码器协商的分辨率/编解码器/帧率，
/// 以及解码器事件和错误的滚动日志。自上而下阅读时，第一个异常区段通常就是卡点。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_video_providers.dart';

/// 显示在自定义图传播放器旁边的完整诊断面板。
// ============================================================
// 流水线状态：每个阶段一行结论
// ============================================================

/// 可嵌入共享侧边面板的调试内容，不包含外层卡片装饰。
///
/// 渲染与 [CustomVideoDebugPanel] 相同的流水线区段，但以普通列形式输出，
/// 便于放入 `VideoSidePanel` 的开发者区段。
class CustomVideoDebugContent extends ConsumerWidget {
  /// 创建 [CustomVideoDebugContent]。
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

/// 各流水线阶段的红黄绿灯摘要。
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
    // 数据流停滞：曾经有数据流动，但超过 2 秒没有新数据到达。
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
// 接入区段：MQTT -> 闸门
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
// 丢包区段：包序列号和丢包率
// ============================================================

/// 显示前导 uint64 序列号，以及由序列号间隔推导出的丢包率。
/// 丢包率上升会直接指向机器人到客户端链路问题：字节根本没有到达，
/// 与后续如何切片或解码无关。
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
// 关键帧区段：切片后流中的 NAL 类型统计
// ============================================================

/// 显示关键帧（IDR/SPS/PPS）是否实际到达，用于快速区分
/// “链路从未发送关键帧”和“关键帧到达但被打包破坏”。
/// 如果 non-IDR（类型 1）增加，而 IDR（类型 5）和 SPS（类型 7）保持 0，
/// 则上游链路或编码器没有提供关键帧。若 IDR/SPS 增加但仍无画面，应怀疑打包或切片模式。
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
// 桥接区段：TCP 桥接吞吐量
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
// 解码器区段：播放器协商结果
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
// 解码器日志：滚动事件和错误记录
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
          // 最新事件放在最前面，避免必须滚动才能看到；面板本身已位于父级 ListView 内。
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
// 共享构建块
// ============================================================

/// 带标题和弱分隔线的一组调试行。
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
