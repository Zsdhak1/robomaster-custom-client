/// 开发者选项 — 调试面板与状态浮层开关
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/settings_providers.dart';

/// 开发者选项子页面。
class DeveloperSettingsScreen extends ConsumerWidget {
  /// 创建 [DeveloperSettingsScreen]。
  const DeveloperSettingsScreen({super.key, this.embedded = false});

  /// 为 true 时只渲染主体，不包含自己的 [Scaffold] 或 [AppBar]。
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
