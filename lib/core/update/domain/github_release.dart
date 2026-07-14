/// GitHub Release 及其资源的数据模型。
library;

import 'package:flutter/foundation.dart';

/// 附加在 GitHub Release 上的单个资源。
@immutable
class GitHubAsset {
  /// 创建 [GitHubAsset]。
  const GitHubAsset({
    required this.name,
    required this.sizeBytes,
    required this.browserDownloadUrl,
    required this.contentType,
  });

  /// 资源文件名，例如 `robomaster-custom-client-1.2.3.apk`。
  final String name;

  /// 文件大小，单位为字节。
  final int sizeBytes;

  /// GitHub 返回的直接下载 URL。
  final String browserDownloadUrl;

  /// GitHub 报告的 MIME 类型。
  final String contentType;

  /// 从 Release API 返回的 JSON 结构解析 GitHub 资源。
  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] as String? ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? 'application/octet-stream',
    );
  }
}

/// 一个 GitHub Release 条目，通常来自 `/repos/{owner}/{repo}/releases/latest`。
@immutable
class GitHubRelease {
  /// 创建 [GitHubRelease]。
  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.assets,
    required this.htmlUrl,
  });

  /// Tag 名称，例如 `v1.2.3`。
  final String tagName;

  /// 可读发布标题。
  final String name;

  /// Markdown 格式的发布说明。
  final String body;

  /// 发布时间戳。
  final DateTime publishedAt;

  /// 该发布附带的资源。
  final List<GitHubAsset> assets;

  /// 浏览器中打开发布页的 URL。
  final String htmlUrl;

  /// 从 Release API 返回的 JSON 结构解析 GitHub Release。
  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    DateTime? parsed;
    final raw = json['published_at'] as String?;
    if (raw != null && raw.isNotEmpty) {
      parsed = DateTime.tryParse(raw);
    }
    final assetsJson = json['assets'];
    final assets = <GitHubAsset>[];
    if (assetsJson is List) {
      for (final e in assetsJson) {
        if (e is Map<String, dynamic>) {
          assets.add(GitHubAsset.fromJson(e));
        }
      }
    }
    return GitHubRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: parsed ?? DateTime.now(),
      assets: assets,
      htmlUrl: json['html_url'] as String? ?? '',
    );
  }
}

/// 更新检查结果，可安全展示给 UI。
@immutable
class UpdateCheckResult {
  /// 创建 [UpdateCheckResult]。
  const UpdateCheckResult({
    this.hasUpdate = false,
    this.release,
    this.currentVersion = '',
    this.latestVersion = '',
    this.errorMessage,
    this.isRateLimited = false,
  });

  /// 是否有新版本可用。
  final bool hasUpdate;

  /// 检查成功时得到的最新发布信息。
  final GitHubRelease? release;

  /// 应用当前版本字符串。
  final String currentVersion;

  /// 从 release tag 解析出的最新版本字符串。
  final String latestVersion;

  /// 检查失败时的本地化错误消息；成功时为 null。
  final String? errorMessage;

  /// GitHub 返回 403 时为 true，通常表示触发限流。
  final bool isRateLimited;

  /// 创建表示“已是最新版本”的结果。
  factory UpdateCheckResult.upToDate({
    required String currentVersion,
    required String latestVersion,
  }) {
    return UpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
    );
  }

  /// 创建表示检查失败的结果。
  factory UpdateCheckResult.error({
    required String message,
    required String currentVersion,
    bool isRateLimited = false,
  }) {
    return UpdateCheckResult(
      currentVersion: currentVersion,
      errorMessage: message,
      isRateLimited: isRateLimited,
    );
  }
}
