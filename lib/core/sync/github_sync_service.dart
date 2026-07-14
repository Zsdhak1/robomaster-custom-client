/// 基于 GitHub 的 [RemoteSyncService] 实现。
///
/// 通过 `dart:io` [HttpClient] 调用 GitHub REST Contents API，不引入额外依赖。
/// 共享记录配置和上传的比赛记录都存放在同一个仓库中，仓库内路径来自 [RemoteSyncConfig]。
///
/// 每个方法都会优雅降级：失败时返回失败的 [SyncResult]、null 或空列表，而不是向外抛出，
/// 避免 UI 因网络或认证错误崩溃。个人访问令牌只会放入 `Authorization` 头，
/// 不会写入日志或 [SyncResult] 消息。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../features/data_export/domain/match_record.dart';
import 'remote_sync_service.dart';

/// 通过 GitHub Contents API 同步配置和记录。
class GitHubSyncService implements RemoteSyncService {
  /// 使用 [config] 创建 [GitHubSyncService]。
  GitHubSyncService({required this.config, HttpClient? httpClient})
      : _client = httpClient ?? HttpClient();

  /// 远程位置和凭据。
  final RemoteSyncConfig config;

  final HttpClient _client;

  /// GitHub REST API 主机。
  static const String _apiHost = 'api.github.com';

  /// 单个网络请求的超时时间。
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

  /// 拉取并解码仓库文件内容和 sha；未命中时返回 null。
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

  /// 创建或更新仓库文件；先拉取已有 sha，避免更新时触发 409 冲突。
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

  /// 构建 `/repos/{owner}/{repo}/contents/{路径}` URL 路径。
  String _contentsPath(String inRepoPath) {
    final clean = inRepoPath.startsWith('/')
        ? inRepoPath.substring(1)
        : inRepoPath;
    return '/repos/${config.repository}/contents/$clean';
  }

  /// 执行已认证请求，并读取完整响应体。
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
    // 仅在存在令牌时认证；公开读取可匿名访问，空 Bearer 头会导致 401。
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

  /// 将 HTTP 错误响应映射为面向用户的消息，并避免泄漏令牌。
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
      // 忽略非 JSON 错误响应体。
    }
    return 'GitHub 返回错误 $code$detail';
  }

  /// 释放底层 [HttpClient]。
  void dispose() => _client.close(force: true);
}

/// 从 GitHub 拉取到的仓库文件。
class _RemoteFile {
  const _RemoteFile({required this.bytes, required this.sha});

  final List<int> bytes;
  final String sha;
}

/// 最小响应载体，包含状态码和已解码文本响应体。
class _Response {
  const _Response({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
