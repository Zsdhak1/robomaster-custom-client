/// 开发者选项 — 调试面板与状态浮层开关
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/settings_providers.dart';

/// Sub-screen for developer options.
class DeveloperSettingsScreen extends ConsumerWidget {
  /// Creates a [DeveloperSettingsScreen].
  const DeveloperSettingsScreen({super.key, this.embedded = false});

  /// When true, renders only the body without its own Scaffold/AppBar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _buildBody(context, ref);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('开发者选项')),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('开发者模式'),
            subtitle: const Text('显示视频/仪表盘的 Debug 面板与状态浮层等调试组件'),
            value: ref.watch(developerModeProvider),
            onChanged: (v) =>
                ref.read(developerModeProvider.notifier).set(enabled: v),
          ),
        ),
      ],
    );
  }
}
