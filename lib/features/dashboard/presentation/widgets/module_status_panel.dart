/// 已明确出现模块的当前可用性面板。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../logic/module_status_monitor.dart';
import '../module_status_strings.dart';

/// 在任一模块离线时展示已知模块的当前状态。
class ModuleStatusPanel extends ConsumerWidget {
  /// 创建 [ModuleStatusPanel]。
  const ModuleStatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(moduleStatusMonitorProvider).statuses;
    final entries = _sortedStatuses(statuses);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: context.insetAll(12),
      child: Card(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        child: Padding(
          padding: context.insetAll(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelHeader(count: entries.length),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => context.sizedBox(h: 8),
                  itemBuilder: (_, index) =>
                      _ModuleStatusRow(entry: entries[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.memory_outlined,
          color: scheme.onSurface,
          size: context.iconSize(20),
        ),
        context.sizedBox(w: 8),
        Text(
          moduleStatusPanelTitle,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text('$count', style: context.textTheme.bodySmall),
      ],
    );
  }
}

class _ModuleStatusRow extends StatelessWidget {
  const _ModuleStatusRow({required this.entry});

  final MapEntry<RobotModuleType, ModuleAvailability> entry;

  @override
  Widget build(BuildContext context) {
    final isOffline = entry.value == ModuleAvailability.offline;
    final scheme = Theme.of(context).colorScheme;
    final foreground = isOffline ? scheme.onErrorContainer : scheme.onSurface;
    final background = isOffline
        ? scheme.errorContainer
        : scheme.surfaceContainerLow;

    return Container(
      color: background,
      padding: context.insetAll(8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              moduleStatusModuleLabel(entry.key),
              style: context.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
          Text(
            moduleStatusAvailabilityLabel(entry.value),
            style: context.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

List<MapEntry<RobotModuleType, ModuleAvailability>> _sortedStatuses(
  Map<RobotModuleType, ModuleAvailability> statuses,
) {
  final entries = statuses.entries.toList()..sort(_compareStatuses);
  return entries;
}

int _compareStatuses(
  MapEntry<RobotModuleType, ModuleAvailability> first,
  MapEntry<RobotModuleType, ModuleAvailability> second,
) {
  final availability = _availabilityOrder(
    first.value,
  ).compareTo(_availabilityOrder(second.value));
  return availability != 0
      ? availability
      : first.key.index.compareTo(second.key.index);
}

int _availabilityOrder(ModuleAvailability availability) {
  return availability == ModuleAvailability.offline ? 0 : 1;
}
