/// 仪表盘 — 机器人列表显示模式
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/settings_providers.dart';
import 'widgets/kill_estimate_settings_section.dart';

/// 仪表盘显示偏好子页面。
class DashboardSettingsScreen extends ConsumerWidget {
  const DashboardSettingsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dashboardDisplayModeProvider);
    final body = _buildBody(context, ref, mode);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('仪表盘')),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    DashboardDisplayMode mode,
  ) {
    final showHealthTrend = ref.watch(showHealthTrendProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 4),
              Text(
                '选择机器人列表的显示模式。',
                style: context.textTheme.bodySmall!.copyWith(
                  color: rmTextSecondary(context),
                ),
              ),
              const SizedBox(height: 12),
              for (final option in DashboardDisplayMode.values)
                _ModeTile(
                  mode: option,
                  selected: option == mode,
                  onTap: () =>
                      ref.read(dashboardDisplayModeProvider.notifier).state =
                          option,
                ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '底部面板设置',
                style: context.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                title: const Text('显示血量趋势图'),
                subtitle: Text(
                  '关闭后底部区域将切换为操作面板与连接质量面板',
                  style: context.textTheme.bodySmall!.copyWith(
                    color: rmTextSecondary(context),
                  ),
                ),
                value: showHealthTrend,
                onChanged: (v) =>
                    ref.read(showHealthTrendProvider.notifier).set(enabled: v),
              ),
              const SizedBox(height: 12),
              const KillEstimateSettingsSection(),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单个可选择的显示模式卡片。
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final DashboardDisplayMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? color : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: context.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: context.textTheme.bodySmall!.copyWith(
                        color: rmTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
