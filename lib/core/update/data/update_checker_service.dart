/// Service that checks the GitHub Releases API for the latest version.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/github_release.dart';
import 'version_comparator.dart';

/// Talks to the GitHub Releases API to determine whether a newer app version
/// is available.
class UpdateCheckerService {
  /// Creates an [UpdateCheckerService].
  UpdateCheckerService({
    this.owner = 'Zsdhak1',
    this.repo = 'robomaster-custom-client',
    this.timeout = const Duration(seconds: 10),
    HttpClient? httpClient,
    this._currentVersion,
  }) : _client = httpClient ?? HttpClient();

  /// Repository owner.
  final String owner;

  /// Repository name.
  final String repo;

  /// Request timeout.
  final Duration timeout;

  final HttpClient _client;
  final String? _currentVersion;

  /// GitHub REST API host.
  static const String _apiHost = 'api.github.com';

  /// Fetches the latest release and compares it with the current version.
  ///
  /// Never throws. On any failure an [UpdateCheckResult.error] is returned
  /// so the UI can degrade gracefully.
  Future<UpdateCheckResult> checkForUpdate() async {
    final currentVersion = _currentVersion ?? '';
    try {
      final response = await _request(
        'GET',
        '/repos/$owner/$repo/releases/latest',
      );
      return _handleResponse(response, currentVersion);
    } on TimeoutException {
      return UpdateCheckResult.error(
        message: '请求超时，请检查网络连接',
        currentVersion: currentVersion,
      );
    } on SocketException {
      return UpdateCheckResult.error(
        message: '网络连接失败，请检查网络',
        currentVersion: currentVersion,
      );
    } on Exception catch (_) {
      return UpdateCheckResult.error(
        message: '检查更新失败',
        currentVersion: currentVersion,
      );
    }
  }

  UpdateCheckResult _handleResponse(_Response response, String currentVersion) {
    if (response.statusCode == HttpStatus.notFound) {
      return UpdateCheckResult.error(
        message: '暂无已发布版本',
        currentVersion: currentVersion,
      );
    }
    if (response.statusCode == HttpStatus.forbidden) {
      return UpdateCheckResult.error(
        message: 'GitHub API 限流，请稍后重试',
        currentVersion: currentVersion,
        isRateLimited: true,
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      return UpdateCheckResult.error(
        message: 'GitHub 返回错误 ${response.statusCode}',
        currentVersion: currentVersion,
      );
    }
    return _parseRelease(response.body, currentVersion);
  }

  UpdateCheckResult _parseRelease(String body, String currentVersion) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      return UpdateCheckResult.error(
        message: 'GitHub 返回数据格式异常',
        currentVersion: currentVersion,
      );
    }

    final release = GitHubRelease.fromJson(json);
    final latestVersion = release.tagName;
    if (latestVersion.isEmpty) {
      return UpdateCheckResult.error(
        message: '最新版本号为空',
        currentVersion: currentVersion,
      );
    }

    final hasUpdate = isNewerVersion(currentVersion, latestVersion);
    return UpdateCheckResult(
      hasUpdate: hasUpdate,
      release: release,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
    );
  }

  Future<_Response> _request(String method, String path) async {
    final uri = Uri.https(_apiHost, path);
    final request = await _client.openUrl(method, uri).timeout(timeout);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set('X-GitHub-Api-Version', '2022-11-28')
      ..set(HttpHeaders.userAgentHeader, 'robomaster-custom-client');
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    return _Response(statusCode: response.statusCode, body: body);
  }

  /// Releases the underlying HTTP client.
  void dispose() => _client.close(force: true);
}

class _Response {
  const _Response({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
