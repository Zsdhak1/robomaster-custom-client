/// 硬件解码器（libmpv `hwdec`）选择页，是设置中的二级页面。
///
/// 与参考“硬件解码器”页面保持一致：单选列表中即使选择了不受支持的模式，也会回退到
/// 软件解码。该设置作用于 media_kit 后端。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/settings_providers.dart';

/// [HwdecMode] 选项的全屏单选列表。
class HwdecScreen extends ConsumerWidget {
  /// 创建 [HwdecScreen]。
  const HwdecScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(hwdecModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('硬件解码器')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              '选择不受支持的解码器将回退到软件解码',
              style: context.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade600,
              ),
            ),
          ),
          for (final mode in HwdecMode.values)
            _HwdecTile(
              mode: mode,
              selected: mode == current,
              onTap: () => ref.read(hwdecModeProvider.notifier).set(mode),
            ),
        ],
      ),
    );
  }
}

/// 可选择的 hwdec 选项行。
class _HwdecTile extends StatelessWidget {
  const _HwdecTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final HwdecMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          mode.label,
          style: context.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          mode.description,
          style: context.textTheme.bodySmall!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? color : Colors.grey,
        ),
      ),
    );
  }
}
