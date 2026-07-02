/// 常规 — 主题外观、当前阵营
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../connection/domain/robot_identity.dart';
import '../logic/settings_providers.dart';

/// Sub-screen for general preferences: side banner and theme mode.
class GeneralSettingsScreen extends ConsumerWidget {
  /// Creates a [GeneralSettingsScreen].
  const GeneralSettingsScreen({super.key, this.embedded = false});

  /// When true, renders only the body content without its own Scaffold/AppBar
  /// (used by the settings master-detail panel).
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownIsBlue = isBlueSide(ref.watch(selectedRobotIdProvider));
    final body = _buildBody(context, ref, ownIsBlue);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('常规')),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, bool ownIsBlue) {
    return ListView(
      padding: context.insetAll(16),
      children: [
        _SideBanner(ownIsBlue: ownIsBlue),
        context.sizedBox(h: 24),
        ..._buildAppearanceSection(context, ref),
      ],
    );
  }

  List<Widget> _buildAppearanceSection(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return [
      Text(
        '主题外观',
        style: context.textTheme.titleSmall!.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (v) {
            if (v != null) {
              ref.read(themeModeProvider.notifier).set(v);
            }
          },
          child: Column(
            children: [
              for (final option in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: option,
                  title: Text(_themeModeLabel(option)),
                  secondary: Icon(_themeModeIcon(option)),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '亮色',
        ThemeMode.dark => '暗色',
      };

  IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto,
        ThemeMode.light => Icons.light_mode,
        ThemeMode.dark => Icons.dark_mode,
      };
}

/// Banner showing which side the client logged in as.
class _SideBanner extends StatelessWidget {
  const _SideBanner({required this.ownIsBlue});

  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        leading: Icon(Icons.shield, color: color),
        title: Text(ownIsBlue ? '己方：蓝方' : '己方：红方'),
        subtitle: const Text('阵营由登录页选择的机器人身份决定'),
      ),
    );
  }
}
