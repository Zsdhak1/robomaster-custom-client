/// Dialog that presents a new release and lets the user download it.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../data/installer_downloader.dart';
import '../domain/github_release.dart';

/// Shows a dialog describing [release] and offering download actions.
class UpdateDialog extends ConsumerWidget {
  /// Creates an [UpdateDialog].
  const UpdateDialog({
    required this.release,
    required this.currentVersion,
    required this.latestVersion,
    super.key,
  });

  /// The latest GitHub release to present.
  final GitHubRelease release;

  /// Current app version string.
  final String currentVersion;

  /// Latest version string parsed from the release tag.
  final String latestVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = pickBestAsset(release.assets);
    final hasMatchingAsset = selected != null && _matchesCurrentPlatform(selected);

    return AlertDialog(
      title: _buildTitle(context),
      content: _buildContent(context, selected),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('忽略'),
        ),
        TextButton(
          onPressed: () => _openReleasePage(context),
          child: const Text('浏览器打开'),
        ),
        ElevatedButton(
          onPressed: hasMatchingAsset ? () => _download(context, selected) : null,
          child: Text(_downloadButtonLabel(selected)),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        const Expanded(child: Text('发现新版本')),
      ],
    );
  }

  Widget _buildContent(BuildContext context, GitHubAsset? selected) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _VersionBanner(
              currentVersion: currentVersion,
              latestVersion: latestVersion,
            ),
            const SizedBox(height: 16),
            Text(
              '发布时间：${_formatDate(release.publishedAt)}',
              style: context.textTheme.bodySmall!.copyWith(
                color: rmTextSecondary(context),
              ),
            ),
            const SizedBox(height: 12),
            _ReleaseNotes(body: release.body),
            const SizedBox(height: 16),
            _AssetList(assets: release.assets, selected: selected),
          ],
        ),
      ),
    );
  }

  bool _matchesCurrentPlatform(GitHubAsset asset) {
    final name = asset.name.toLowerCase();
    if (Platform.isAndroid) return name.endsWith('.apk');
    if (Platform.isLinux) {
      return name.endsWith('.tar.gz') ||
          name.endsWith('.deb') ||
          name.endsWith('.appimage') ||
          name.endsWith('.zip');
    }
    if (Platform.isWindows) {
      return name.endsWith('.exe') || name.endsWith('.zip');
    }
    if (Platform.isMacOS) {
      return name.endsWith('.dmg') || name.endsWith('.zip');
    }
    return false;
  }

  String _downloadButtonLabel(GitHubAsset? asset) {
    if (asset == null) return '无可用安装包';
    if (Platform.isAndroid) return '下载并安装 APK';
    return '下载 ${asset.name}';
  }

  Future<void> _download(BuildContext context, GitHubAsset asset) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在下载安装包…'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final result = await downloadOrLaunchInstaller(asset);
    if (!context.mounted) return;
    messenger?.hideCurrentSnackBar();

    if (result.ok) {
      context.showSuccessSnack(result.message);
      Navigator.of(context).pop();
    } else {
      context.showErrorSnack(result.message);
    }
  }

  Future<void> _openReleasePage(BuildContext context) async {
    final result = await openReleasePage(release.htmlUrl);
    if (!context.mounted) return;
    if (!result.ok) {
      context.showErrorSnack(result.message);
    }
  }

  static String _formatDate(DateTime d) {
    return '${d.year}-${_two(d.month)}-${_two(d.day)} ${d.hour}:${_two(d.minute)}';
  }

  static String _two(int n) => n >= 10 ? '$n' : '0$n';
}

class _VersionBanner extends StatelessWidget {
  const _VersionBanner({
    required this.currentVersion,
    required this.latestVersion,
  });

  final String currentVersion;
  final String latestVersion;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(rmCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最新版本：$latestVersion',
            style: context.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '当前版本：$currentVersion',
            style: context.textTheme.bodySmall!.copyWith(
              color: rmTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '更新内容',
          style: context.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: rmTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(rmCardRadius),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              body.isEmpty ? '（无详细说明）' : body,
              style: context.textTheme.bodySmall!.copyWith(
                color: rmTextPrimary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AssetList extends StatelessWidget {
  const _AssetList({required this.assets, required this.selected});

  final List<GitHubAsset> assets;
  final GitHubAsset? selected;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Text(
        '该版本未上传安装包',
        style: context.textTheme.bodySmall!.copyWith(
          color: rmTextSecondary(context),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '安装包',
          style: context.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: rmTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        ...assets.map((asset) {
          final isSelected = selected != null && asset.name == selected!.name;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(
                _assetIcon(asset),
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                size: 20,
              ),
              title: Text(
                asset.name,
                style: context.textTheme.bodySmall!.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '${formatBytes(asset.sizeBytes)} · ${asset.contentType}',
                style: context.textTheme.bodySmall!.copyWith(
                  color: rmTextSecondary(context),
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary, size: 18)
                  : null,
            ),
          );
        }),
      ],
    );
  }

  IconData _assetIcon(GitHubAsset asset) {
    final name = asset.name.toLowerCase();
    if (name.endsWith('.apk')) return Icons.android;
    if (name.endsWith('.exe')) return Icons.desktop_windows;
    if (name.endsWith('.deb') || name.endsWith('.tar.gz') || name.endsWith('.appimage')) {
      return Icons.computer;
    }
    if (name.endsWith('.dmg')) return Icons.laptop_mac;
    return Icons.insert_drive_file;
  }
}
