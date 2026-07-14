/// 关于页面，展示版本信息、仓库链接和手动更新检查入口。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/update/domain/github_release.dart';
import '../../../core/update/logic/update_providers.dart';
import '../../../core/update/presentation/update_dialog.dart';

/// 显示应用元数据，并允许用户手动检查更新。
class AboutScreen extends StatelessWidget {
  /// 创建 [AboutScreen]。
  const AboutScreen({super.key, this.embedded = false});

  /// 为 true 时只渲染主体，不包含自己的 [Scaffold] 或 [AppBar]。
  final bool embedded;

  static const String _repoUrl =
      'https://github.com/Zsdhak1/robomaster-custom-client';

  @override
  Widget build(BuildContext context) {
    if (embedded) return const _AboutBody();
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: const _AboutBody(),
    );
  }
}

class _AboutBody extends ConsumerWidget {
  const _AboutBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final updateAsync = ref.watch(updateCheckResultProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AboutHeader(versionAsync: versionAsync),
            const SizedBox(height: 24),
            _UpdateCard(updateAsync: updateAsync),
            const SizedBox(height: 16),
            const _RepoCard(),
            const SizedBox(height: 16),
            const _InfoCard(),
          ],
        ),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.versionAsync});

  final AsyncValue<String> versionAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.precision_manufacturing,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'WOD Client',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _VersionText(versionAsync: versionAsync),
      ],
    );
  }
}

class _VersionText extends StatelessWidget {
  const _VersionText({required this.versionAsync});

  final AsyncValue<String> versionAsync;

  @override
  Widget build(BuildContext context) {
    return versionAsync.when(
      data: (v) => Text(
        '版本 $v',
        style: context.textTheme.bodyMedium!.copyWith(
          color: rmTextSecondary(context),
        ),
      ),
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (err, _) => Text(
        '版本未知',
        style: context.textTheme.bodyMedium!.copyWith(
          color: rmTextSecondary(context),
        ),
      ),
    );
  }
}

class _UpdateCard extends ConsumerWidget {
  const _UpdateCard({required this.updateAsync});

  final AsyncValue<UpdateCheckResult> updateAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChecking = updateAsync.isLoading;
    final result = updateAsync.valueOrNull;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('检查更新'),
            subtitle: Text(_subtitle(result, isChecking)),
            trailing: isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: isChecking ? null : () => _checkUpdate(context, ref),
          ),
          if (result?.hasUpdate ?? false)
            _ViewUpdateButton(result: result!),
        ],
      ),
    );
  }

  String _subtitle(UpdateCheckResult? result, bool isChecking) {
    if (isChecking) return '正在检查新版本…';
    if (result == null) return '点击检查是否有新版本';
    if (result.errorMessage != null) return result.errorMessage!;
    if (result.hasUpdate) return '发现新版本 ${result.latestVersion}';
    return '当前已是最新版本';
  }

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    ref.invalidate(updateCheckResultProvider);
    final future = ref.read(updateCheckResultProvider.future);
    final result = await future;
    if (!context.mounted) return;

    if (result.errorMessage != null) {
      context.showErrorSnack(result.errorMessage!);
      return;
    }
    if (result.hasUpdate && result.release != null) {
      _showUpdateDialog(context, result);
    } else {
      context.showInfoSnack('当前已是最新版本');
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateCheckResult result) {
    showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(
        release: result.release!,
        currentVersion: result.currentVersion,
        latestVersion: result.latestVersion,
      ),
    );
  }
}

class _ViewUpdateButton extends StatelessWidget {
  const _ViewUpdateButton({required this.result});

  final UpdateCheckResult result;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_browser),
          label: const Text('查看新版本'),
          onPressed: () => _showUpdateDialog(context),
        ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => UpdateDialog(
        release: result.release!,
        currentVersion: result.currentVersion,
        latestVersion: result.latestVersion,
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.code),
        title: const Text('开源仓库'),
        subtitle: const Text(
          AboutScreen._repoUrl,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => _openRepo(context),
      ),
    );
  }

  Future<void> _openRepo(BuildContext context) async {
    final uri = Uri.parse(AboutScreen._repoUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        context.showErrorSnack('无法打开浏览器');
      }
    } on Exception catch (e) {
      if (context.mounted) {
        context.showErrorSnack('无法打开链接：$e');
      }
    }
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '协议适配'),
            const SizedBox(height: 8),
            Text(
              'RoboMaster 2026 自定义客户端协议 V1.3.1\n'
              'MQTT 3333 控制 / 状态链路 + UDP 3334 HEVC 视频流',
              style: context.textTheme.bodySmall!.copyWith(
        color: rmTextSecondary(context),
      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.textTheme.titleSmall!.copyWith(
        fontWeight: FontWeight.bold,
        color: rmTextPrimary(context),
      ),
    );
  }
}
