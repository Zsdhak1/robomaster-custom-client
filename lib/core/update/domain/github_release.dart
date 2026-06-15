/// Data models for a GitHub Release and its assets.
library;

import 'package:flutter/foundation.dart';

/// A single release asset attached to a GitHub release.
@immutable
class GitHubAsset {
  /// Creates a [GitHubAsset].
  const GitHubAsset({
    required this.name,
    required this.sizeBytes,
    required this.browserDownloadUrl,
    required this.contentType,
  });

  /// File name of the asset, e.g. `robomaster-custom-client-1.2.3.apk`.
  final String name;

  /// Size in bytes.
  final int sizeBytes;

  /// Direct download URL returned by GitHub.
  final String browserDownloadUrl;

  /// MIME type reported by GitHub.
  final String contentType;

  /// Parses a GitHub asset from the JSON shape returned by the Releases API.
  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] as String? ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      browserDownloadUrl: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? 'application/octet-stream',
    );
  }
}

/// A GitHub release entry, usually the latest one returned by
/// `/repos/{owner}/{repo}/releases/latest`.
@immutable
class GitHubRelease {
  /// Creates a [GitHubRelease].
  const GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.assets,
    required this.htmlUrl,
  });

  /// Tag name, e.g. `v1.2.3`.
  final String tagName;

  /// Human-readable release title.
  final String name;

  /// Release notes in Markdown.
  final String body;

  /// Publication timestamp.
  final DateTime publishedAt;

  /// Attachments for this release.
  final List<GitHubAsset> assets;

  /// URL of the release page in a browser.
  final String htmlUrl;

  /// Parses a GitHub release from the JSON shape returned by the Releases API.
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

/// Result of an update check, always safe to display.
@immutable
class UpdateCheckResult {
  /// Creates an [UpdateCheckResult].
  const UpdateCheckResult({
    this.hasUpdate = false,
    this.release,
    this.currentVersion = '',
    this.latestVersion = '',
    this.errorMessage,
    this.isRateLimited = false,
  });

  /// Whether a newer version is available.
  final bool hasUpdate;

  /// The latest release when the check succeeded.
  final GitHubRelease? release;

  /// The app's current version string.
  final String currentVersion;

  /// The latest version string parsed from the release tag.
  final String latestVersion;

  /// Localized error message when the check failed; null on success.
  final String? errorMessage;

  /// True when GitHub returned 403 (likely rate-limited).
  final bool isRateLimited;

  /// Convenience: a result representing "already up to date".
  factory UpdateCheckResult.upToDate({
    required String currentVersion,
    required String latestVersion,
  }) {
    return UpdateCheckResult(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
    );
  }

  /// Convenience: a result representing a check failure.
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
