/// 仪表盘底部的数据录制状态面板。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../data_export/domain/data_recorder.dart';
import '../../../data_export/logic/data_recorder_provider.dart';

/// 展示当前内存录制器的运行状态。
class RecordingStatusPanel extends ConsumerStatefulWidget {
  /// 创建录制状态面板。
  const RecordingStatusPanel({super.key});

  @override
  ConsumerState<RecordingStatusPanel> createState() =>
      _RecordingStatusPanelState();
}

class _RecordingStatusPanelState extends ConsumerState<RecordingStatusPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(dataRecorderProvider).isRecording) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataRecorderProvider);
    final scheme = Theme.of(context).colorScheme;
    final color = state.isRecording ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.zero,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: context.insetAll(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, state, color),
              context.sizedBox(h: 10),
              _detail(context, '消息', '${state.totalCount}'),
              _detail(context, '时长', _duration(state.duration)),
              _detail(
                context,
                '容量',
                '${state.totalCount}/${state.maxMessages}',
              ),
              if (state.startTime != null)
                _detail(context, '开始', _time(state.startTime)),
              if (!state.isRecording && state.stopTime != null)
                _detail(context, '停止', _time(state.stopTime)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DataRecorderState state, Color color) {
    return Row(
      children: [
        Icon(
          state.isRecording ? Icons.fiber_manual_record : Icons.stop_circle,
          color: color,
          size: context.iconSize(18),
        ),
        context.sizedBox(w: 6),
        Expanded(
          child: Text(
            state.isRecording ? '正在录制' : '录制已停止',
            style: context.textTheme.titleSmall!.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(4)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.textTheme.bodySmall)),
          Text(
            value,
            style: context.textTheme.labelMedium!.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _duration(Duration? duration) {
    if (duration == null) return '—';
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _time(DateTime? time) {
    if (time == null) return '—';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
