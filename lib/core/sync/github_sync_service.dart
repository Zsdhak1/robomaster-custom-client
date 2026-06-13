/// GitHub-backed implementation of [RemoteSyncService].
///
/// Uses the GitHub REST Contents API over `dart:io` [HttpClient] (no extra
/// package dependency). The shared record configuration and uploaded match
/// recordings live inside a single repository, addressed by the in-repo paths
/// from [RemoteSyncConfig].
///
/// Every method degrades gracefully — failures return a failed [SyncResult],
/// null, or an empty list rather than throwing — so the UI never crashes on a
/// network or auth error. The personal access token is sent only in the
/// `Authorization` header and is never written to a log or a [SyncResult]
/// message.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/data_export/domain/match_record.dart';
import 'remote_sync_service.dart';

/// Talks to the GitHub Contents API to sync config and recordings.
class GitHubSyncService implements RemoteSyncService {
  /// Creates a [GitHubSyncService] from [config].
  GitHubSyncService({required this.config, HttpClient? httpClient})
      : _client = httpClient ?? HttpClient();

  /// Remote location and credentials.
  final RemoteSyncConfig config;

  final HttpClient _client;

  /// GitHub REST API host.
  static const String _apiHost = 'api.github.com';

  /// Network timeout for a single request.
  static const Duration _timeout = Duration(seconds: 20);

  @override
  Future<Map<String, dynamic>?> pullRecordConfig() async {
    if (!config.canPull) return null;
    final file = await _getContent(config.configPath);
    if (file == null) return null;
    try {
      final decoded = jsonDecode(utf8.decode(file.bytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<SyncResult> pushRecordConfig(Map<String, dynamic> configJson) async {
    if (!config.canPush) {
      return SyncResult.failure('推送需要访问令牌（请在设置中填写 PAT）');
    }
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(configJson),
    );
    return _putContent(
      path: config.configPath,
      bytes: bytes,
      message: 'chore: update record config',
    );
  }

  @override
  Future<List<RemoteRecordRef>> listRemoteRecords() async {
    if (!config.canPull) return [];
    try {
      final response = await _request('GET', _contentsPath(config.recordsDir));
      if (response.statusCode != HttpStatus.ok) return [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .where((e) => e['type'] == 'file')
          .where((e) => (e['name'] as String? ?? '').endsWith('.json'))
          .map(
            (e) => RemoteRecordRef(
              fileName: e['name'] as String,
              remotePath: e['path'] as String,
              sizeBytes: (e['size'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();
    } on Exception {
      return [];
    }
  }

  @override
  Future<String?> downloadRecord(RemoteRecordRef ref) async {
    if (!config.canPull) return null;
    final localDir = config.localRecordsDir;
    if (localDir.isEmpty) return null;

    final file = await _getContent(ref.remotePath);
    if (file == null) return null;

    try {
      final target = File('$localDir${Platform.pathSeparator}${ref.fileName}');
      await target.writeAsBytes(file.bytes);
      return target.path;
    } on Exception {
      return null;
    }
  }

  @override
  Future<SyncResult> uploadRecord(MatchRecord record) async {
    if (!config.canPush) {
      return SyncResult.failure('上传需要访问令牌（请在设置中填写 PAT）');
    }
    final List<int> bytes;
    try {
      bytes = await File(record.filePath).readAsBytes();
    } on Exception catch (e) {
      return SyncResult.failure('读取本地文件失败: $e');
    }
    final remotePath = '${config.recordsDir}/${record.fileName}';
    return _putContent(
      path: remotePath,
      bytes: bytes,
      message: 'chore: upload recording ${record.fileName}',
    );
  }

  /// Fetches and decodes a repository file's content + sha, or null on miss.
  Future<_RemoteFile?> _getContent(String path) async {
    try {
      final response = await _request('GET', _contentsPath(path));
      if (response.statusCode != HttpStatus.ok) return null;
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final contentB64 = (json['content'] as String?)?.replaceAll('\n', '');
      final sha = json['sha'] as String?;
      if (contentB64 == null || sha == null) return null;
      return _RemoteFile(bytes: base64Decode(contentB64), sha: sha);
    } on Exception {
      return null;
    }
  }

  /// Creates or updates a repository file, fetching the existing sha first so
  /// updates do not 409-conflict.
  Future<SyncResult> _putContent({
    required String path,
    required List<int> bytes,
    required String message,
  }) async {
    try {
      final existing = await _getContent(path);
      final body = <String, dynamic>{
        'message': message,
        'content': base64Encode(bytes),
        'branch': config.branch,
        if (existing != null) 'sha': existing.sha,
      };
      final response = await _request(
        'PUT',
        _contentsPath(path),
        body: jsonEncode(body),
      );
      if (response.statusCode == HttpStatus.ok ||
          response.statusCode == HttpStatus.created) {
        return SyncResult.success('已同步到 GitHub');
      }
      return SyncResult.failure(_describeError(response));
    } on TimeoutException {
      return SyncResult.failure('请求超时，请检查网络');
    } on Exception catch (e) {
      return SyncResult.failure('同步失败: $e');
    }
  }

  /// Builds the `/repos/{owner}/{repo}/contents/{path}` URL path.
  String _contentsPath(String inRepoPath) {
    final clean = inRepoPath.startsWith('/')
        ? inRepoPath.substring(1)
        : inRepoPath;
    return '/repos/${config.repository}/contents/$clean';
  }

  /// Executes an authenticated request and reads the full response body.
  Future<_Response> _request(
    String method,
    String path, {
    String? body,
  }) async {
    final uri = Uri.https(_apiHost, path, {'ref': config.branch});
    final request = await _client.openUrl(method, uri).timeout(_timeout);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set('X-GitHub-Api-Version', '2022-11-28')
      ..set(HttpHeaders.userAgentHeader, 'robomaster-custom-client');
    // Only authenticate when a token is present: public reads work
    // unauthenticated, and an empty Bearer header would 401.
    if (config.token.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${config.token}',
      );
    }
    if (body != null) {
      final encoded = utf8.encode(body);
      request.headers.contentType = ContentType.json;
      request.add(encoded);
    }
    final response = await request.close().timeout(_timeout);
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    return _Response(statusCode: response.statusCode, body: text);
  }

  /// Maps an HTTP error response to a user-facing message (no token leakage).
  String _describeError(_Response response) {
    final code = response.statusCode;
    if (code == HttpStatus.unauthorized) return '认证失败：令牌无效或已过期';
    if (code == HttpStatus.forbidden) return '权限不足或触发限流（403）';
    if (code == HttpStatus.notFound) return '仓库或路径不存在（404）';
    if (code == HttpStatus.conflict) return '版本冲突，请重试（409）';
    String detail = '';
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic> && json['message'] is String) {
        detail = '：${json['message']}';
      }
    } on FormatException {
      // Ignore non-JSON error bodies.
    }
    return 'GitHub 返回错误 $code$detail';
  }

  /// Releases the underlying [HttpClient].
  void dispose() => _client.close(force: true);
}

/// A repository file fetched from GitHub.
class _RemoteFile {
  const _RemoteFile({required this.bytes, required this.sha});

  final List<int> bytes;
  final String sha;
}

/// Minimal response holder (status + decoded text body).
class _Response {
  const _Response({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
