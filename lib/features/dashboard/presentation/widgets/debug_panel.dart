/// Expandable debug panel showing all received MQTT topic data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/debug_message_log.dart';

/// Expandable overlay panel displaying raw MQTT message data.
class DebugPanel extends ConsumerWidget {
  /// Creates a [DebugPanel].
  const DebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(debugMessageLogProvider);
    final topics = log.topicSet.toList()..sort();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(context.rmCardRadius),
      child: Container(
        width: context.sp(480),
        height: context.sp(360),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(context.rmCardRadius),
          border: Border.all(color: Colors.grey.shade700),
        ),
        child: Column(
          children: [
            _buildHeader(context, ref, log.entries.length),
            Expanded(child: _buildBody(topics, log)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int count) {
    return Container(
      padding: context.insetSym(h: 12, v: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.rmCardRadius),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, color: Colors.green, size: 18),
          context.sizedBox(w: 8),
          Text(
            'Debug — $count 条记录',
            style: TextStyle(
              color: Colors.white,
              fontSize: context.fontSize(14),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 18),
            tooltip: '清空',
            onPressed: () => ref.read(debugMessageLogProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<String> topics, DebugMessageLog log) {
    if (topics.isEmpty) {
      return const Center(
        child: Text(
          '暂无数据\n等待 MQTT 消息...',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }
    return DefaultTabController(
      length: topics.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: rmPrimaryBlue,
            tabs: topics.map((t) => Tab(text: t)).toList(),
          ),
          Expanded(
            child: TabBarView(
              children: topics
                  .map((t) => _TopicLog(entries: log.forTopic(t)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// List of log entries for a single topic.
class _TopicLog extends StatelessWidget {
  /// Creates a [_TopicLog].
  const _TopicLog({required this.entries});

  final List<DebugLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final reversed = entries.reversed.toList();
    return ListView.builder(
      itemCount: reversed.length,
      padding: context.insetAll(8),
      itemBuilder: (context, index) {
        final entry = reversed[index];
        return _LogEntryTile(entry: entry);
      },
    );
  }
}

/// Single log entry display showing parsed Protobuf fields.
class _LogEntryTile extends StatelessWidget {
  /// Creates a [_LogEntryTile].
  const _LogEntryTile({required this.entry});

  final DebugLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: context.insetOnly(b: 6),
      padding: context.insetAll(8),
      decoration: BoxDecoration(
        color: const Color(0xFF303030),
        borderRadius: BorderRadius.circular(context.sp(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetaRow(context),
          context.sizedBox(h: 6),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context) {
    final time =
        '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Text(
          time,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: context.fontSize(11),
            fontFamily: 'monospace',
          ),
        ),
        context.sizedBox(w: 8),
        Container(
          width: context.sp(8),
          height: context.sp(8),
          decoration: BoxDecoration(
            color: entry.isRecognized ? Colors.green : Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
        context.sizedBox(w: 6),
        Text(
          entry.isRecognized ? '已解析' : '未识别',
          style: TextStyle(
            color: entry.isRecognized ? Colors.green : Colors.orange,
            fontSize: context.fontSize(11),
          ),
        ),
        const Spacer(),
        Text(
          '${entry.rawBytes.length} 字节',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: context.fontSize(10),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (entry.fields.isEmpty) {
      // Unrecognized or empty message: fall back to hex.
      return Text(
        entry.isRecognized ? '(空消息)' : entry.hexSummary,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: context.fontSize(12),
          fontFamily: 'monospace',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entry.fields.map((f) => _buildFieldRow(context, f)).toList(),
    );
  }

  Widget _buildFieldRow(BuildContext context, DebugField field) {
    return Padding(
      padding: context.insetSym(v: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: context.sp(140),
            child: Text(
              field.name,
              style: TextStyle(
                color: rmPrimaryBlue,
                fontSize: context.fontSize(12),
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          context.sizedBox(w: 8),
          Expanded(
            child: Text(
              field.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
