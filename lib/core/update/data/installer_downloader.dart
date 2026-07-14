/// 平台感知的安装包下载和启动辅助函数。
library;

import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/github_release.dart';

const Duration _installerDownloadTimeout = Duration(seconds: 30);

/// 下载或启动安装包的操作结果。
class InstallerResult {
  /// 创建 [InstallerResult]。
  const InstallerResult({required this.ok, this.message = '', this.localPath});

  /// 操作是否成功。
  final bool ok;

  /// 可读详情。
  final String message;

  /// Android 下载安装包后的本地文件路径。
  final String? localPath;

  /// 成功结果。
  factory InstallerResult.success([String message = '', String? path]) {
    return InstallerResult(ok: true, message: message, localPath: path);
  }

  /// 失败结果。
  factory InstallerResult.failure(String message) {
    return InstallerResult(ok: false, message: message);
  }
}

/// 为当前平台选择最合适的安装包资源。
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

/// 以平台合适的方式下载或启动已选资源。
///
/// - Android：将 APK 下载到应用缓存，然后打开文件 URI 触发系统包安装器。
/// - Linux / Windows / macOS：使用用户默认处理程序打开浏览器下载 URL。
///
/// 不向外抛出异常；失败会以 [InstallerResult.failure] 返回。
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
    await response.pipe(file.openWrite()).timeout(_installerDownloadTimeout);

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
  try {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      return InstallerResult.failure('无法打开浏览器');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return InstallerResult.success('已打开浏览器下载');
  } on Exception catch (e) {
    return InstallerResult.failure('打开下载链接失败：$e');
  }
}

/// 在默认浏览器中打开发布页。
Future<InstallerResult> openReleasePage(String htmlUrl) async {
  return _launchBrowser(htmlUrl);
}

/// 将 [bytes] 格式化为可读大小字符串。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}
