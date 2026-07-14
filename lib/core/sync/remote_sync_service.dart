/// 用于将记录配置和比赛记录同步到远程存储的抽象层。
///
/// 当前文件只定义接口，并提供本地空操作实现；后续可以接入 GitHub 仓库等后端，
/// 而无需修改调用方。参见 [RemoteSyncService]。
library;

import '../../features/data_export/domain/match_record.dart';

/// 默认共享仓库用于让每个客户端开箱即用地指向同一个位置。
const String defaultSyncRepository = 'Zsdhak1/custom-client-sync';

/// [defaultSyncRepository] 的默认目标分支。
const String defaultSyncBranch = 'main';

/// 默认 GitHub 个人访问令牌占位值。
///
/// 安全提醒：不要在源码或已提交的二进制中嵌入真实 PAT。GitHub Push Protection
/// 会阻止包含密钥的推送；用户需要在“设置 → 远程同步”中输入自己的 PAT 后再上传记录。
const String defaultSyncToken = '';

/// 远程后端的凭据和路径配置。
///
/// GitHub 实现中，[repository] 为 `owner/repo`，[branch] 为目标分支，
/// [token] 为个人访问令牌，[configPath] / [recordsDir] 为仓库内共享配置和记录路径。
class RemoteSyncConfig {
  /// 创建 [RemoteSyncConfig]。
  const RemoteSyncConfig({
    this.repository = defaultSyncRepository,
    this.branch = defaultSyncBranch,
    this.token = defaultSyncToken,
    this.configPath = 'record_config.json',
    this.recordsDir = 'records',
    this.localRecordsDir = '',
  });

  /// 远程仓库的 `owner/repo` 标识。
  final String repository;

  /// 目标分支。
  final String branch;

  /// 访问令牌；不得写入日志或回显其值。
  final String token;

  /// 仓库内共享记录配置 JSON 的路径。
  final String configPath;

  /// 仓库内存放已上传比赛记录的目录。
  final String recordsDir;

  /// 下载写入的本地目录，通常为导出目录。
  ///
  /// 该字段不会持久化到远程配置，而是在运行时从本地导出目录设置填充。
  final String localRecordsDir;

  /// 是否存在可读取的远程目标；公开拉取不需要令牌。
  bool get canPull => repository.isNotEmpty;

  /// 是否可以推送或上传；写入需要令牌。
  bool get canPush => repository.isNotEmpty && token.isNotEmpty;

  /// 该配置是否已完整填写仓库和令牌。
  ///
  /// 保留给调用方/UI 判断写入操作是否可用；等价于 [canPush]。
  bool get isConfigured => canPush;

  /// 创建替换部分字段后的副本。
  RemoteSyncConfig copyWith({
    String? repository,
    String? branch,
    String? token,
    String? configPath,
    String? recordsDir,
    String? localRecordsDir,
  }) {
    return RemoteSyncConfig(
      repository: repository ?? this.repository,
      branch: branch ?? this.branch,
      token: token ?? this.token,
      configPath: configPath ?? this.configPath,
      recordsDir: recordsDir ?? this.recordsDir,
      localRecordsDir: localRecordsDir ?? this.localRecordsDir,
    );
  }

  /// 从 JSON 还原配置。
  ///
  /// 令牌刻意不在这里持久化；GitHub 实现接入后应单独存入安全存储。
  factory RemoteSyncConfig.fromJson(Map<String, dynamic> json) {
    return RemoteSyncConfig(
      repository: json['repository'] as String? ?? defaultSyncRepository,
      branch: json['branch'] as String? ?? defaultSyncBranch,
      token: json['token'] as String? ?? defaultSyncToken,
      configPath: json['config_path'] as String? ?? 'record_config.json',
      recordsDir: json['records_dir'] as String? ?? 'records',
    );
  }

  /// 序列化为 JSON；按设计排除 [token]。
  Map<String, dynamic> toJson() => {
        'repository': repository,
        'branch': branch,
        'config_path': configPath,
        'records_dir': recordsDir,
      };
}

/// 远程可用但尚未下载的比赛记录引用。
class RemoteRecordRef {
  /// 创建 [RemoteRecordRef]。
  const RemoteRecordRef({
    required this.fileName,
    required this.remotePath,
    this.sizeBytes = 0,
  });

  /// 基础文件名。
  final String fileName;

  /// 用于拉取文件的仓库内路径。
  final String remotePath;

  /// 文件大小，单位为字节；未知时为 0。
  final int sizeBytes;
}

/// 同步操作结果，包含成功标记和面向用户的消息。
class SyncResult {
  /// 创建 [SyncResult]。
  const SyncResult({required this.ok, this.message = ''});

  /// 操作是否成功。
  final bool ok;

  /// 可读详情，显示给用户；不得包含令牌。
  final String message;

  /// 创建成功结果，可附带 [message]。
  static SyncResult success([String message = '']) =>
      SyncResult(ok: true, message: message);

  /// 创建失败结果，并附带 [message]。
  static SyncResult failure(String message) =>
      SyncResult(ok: false, message: message);
}

/// 拉取共享记录配置、并与远程存储交换比赛记录的服务契约。
///
/// 实现不得向 UI 抛出异常；应返回失败 [SyncResult]、null 或空集合，让 UI 能优雅降级。
abstract class RemoteSyncService {
  /// 拉取共享记录配置 JSON。
  ///
  /// 返回原始解码后的 map；不可用时返回 null。调用方会将其传给 `RecordConfig.fromJson`。
  Future<Map<String, dynamic>?> pullRecordConfig();

  /// 将本地记录配置 JSON 推送到远程共享位置。
  Future<SyncResult> pushRecordConfig(Map<String, dynamic> config);

  /// 列出远程可用的比赛记录。
  Future<List<RemoteRecordRef>> listRemoteRecords();

  /// 将 [ref] 下载到本地导出目录，成功时返回本地路径，失败时返回 null。
  Future<String?> downloadRecord(RemoteRecordRef ref);

  /// 将本地 [record] 上传到远程记录目录。
  Future<SyncResult> uploadRecord(MatchRecord record);
}

/// GitHub 后端接入前使用的本地空操作实现。
///
/// 所有方法都会优雅降级：拉取返回 null 或空集合，推送报告“未配置”失败。
/// 调用方先接入该实现，后续替换成 GitHub 实现时无需改调用点。
class NoopRemoteSyncService implements RemoteSyncService {
  /// 创建 [NoopRemoteSyncService]。
  const NoopRemoteSyncService();

  static const SyncResult _notConfigured =
      SyncResult(ok: false, message: '远程同步未配置（GitHub 同步将在后续版本提供）');

  @override
  Future<Map<String, dynamic>?> pullRecordConfig() async => null;

  @override
  Future<SyncResult> pushRecordConfig(Map<String, dynamic> config) async =>
      _notConfigured;

  @override
  Future<List<RemoteRecordRef>> listRemoteRecords() async => [];

  @override
  Future<String?> downloadRecord(RemoteRecordRef ref) async => null;

  @override
  Future<SyncResult> uploadRecord(MatchRecord record) async => _notConfigured;
}
