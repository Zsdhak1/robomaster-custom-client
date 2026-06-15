/// Platform-aware installer download / launch helpers.
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/github_release.dart';

/// Result of attempting to download or launch an installer.
class InstallerResult {
  /// Creates an [InstallerResult].
  const InstallerResult({required this.ok, this.message = '', this.localPath});

  /// Whether the operation succeeded.
  final bool ok;

  /// Human-readable detail.
  final String message;

  /// Local file path when the installer was downloaded on Android.
  final String? localPath;

  /// Successful result.
  factory InstallerResult.success([String message = '', String? path]) {
    return InstallerResult(ok: true, message: message, localPath: path);
  }

  /// Failed result.
  factory InstallerResult.failure(String message) {
    return InstallerResult(ok: false, message: message);
  }
}

/// Picks the best installer asset for the current platform.
GitHubAsset? pickBestAsset(List<GitHubAsset> assets) {
  if (assets.isEmpty) return null;

  if (Platform.isAndroid) {
    return assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith('.apk'),
      orElse: () => assets.first,
    );
  }

  if (Platform.isLinux) {
    const extensions = ['.tar.gz', '.deb', '.appimage', '.zip'];
    for (final ext in extensions) {
      final match = assets.firstWhere(
        (a) => a.name.toLowerCase().endsWith(ext),
        orElse: () => assets.first,
      );
      if (match.name.toLowerCase().endsWith(ext)) return match;
    }
  }

  if (Platform.isWindows) {
    return assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith('.exe') ||
          a.name.toLowerCase().endsWith('.zip'),
      orElse: () => assets.first,
    );
  }

  if (Platform.isMacOS) {
    return assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith('.dmg') ||
          a.name.toLowerCase().endsWith('.zip'),
      orElse: () => assets.first,
    );
  }

  return assets.first;
}

/// Downloads or launches the selected asset in a platform-appropriate way.
///
/// - Android: downloads the APK to the app cache, then launches the file URI
///   to trigger the system package installer.
/// - Linux / Windows / macOS: opens the browser download URL with the user's
///   default handler.
///
/// Never throws; failures are returned as [InstallerResult.failure].
Future<InstallerResult> downloadOrLaunchInstaller(GitHubAsset asset) async {
  if (Platform.isAndroid) {
    return _downloadAndroidApk(asset);
  }
  return _launchBrowser(asset.browserDownloadUrl);
}

Future<InstallerResult> _downloadAndroidApk(GitHubAsset asset) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(asset.browserDownloadUrl);
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      return InstallerResult.failure('下载失败：HTTP ${response.statusCode}');
    }

    final dir = await getTemporaryDirectory();
    final safeName = asset.name.replaceAll(RegExp(r'[^\w\-\.]'), '_');
    final file = File('${dir.path}/$safeName');
    await response.pipe(file.openWrite());

    final fileUri = Uri.file(file.path);
    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
    } else {
      return InstallerResult.failure('无法打开 APK 安装界面，请手动安装');
    }

    return InstallerResult.success('下载完成，请按系统提示安装', file.path);
  } on TimeoutException {
    return InstallerResult.failure('下载超时，请检查网络');
  } on Exception catch (e) {
    return InstallerResult.failure('下载失败：$e');
  } finally {
    client.close();
  }
}

Future<InstallerResult> _launchBrowser(String url) async {
  final uri = Uri.parse(url);
  if (!await canLaunchUrl(uri)) {
    return InstallerResult.failure('无法打开浏览器');
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
  return InstallerResult.success('已打开浏览器下载');
}

/// Opens the release page in the default browser.
Future<InstallerResult> openReleasePage(String htmlUrl) async {
  return _launchBrowser(htmlUrl);
}

/// Formats [bytes] into a human-readable size string.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}
