/// Abstractions for syncing record configuration and match recordings with a
/// remote store (e.g. a shared GitHub repository).
///
/// This file defines the *interfaces* only. The current build ships a local
/// no-op implementation; a GitHub-backed implementation can be dropped in next
/// phase without touching callers. See [RemoteSyncService].
library;

import '../../features/data_export/domain/match_record.dart';

/// Identifies a remote backend and its credentials/location.
///
/// For the GitHub implementation: [repository] is `owner/repo`, [branch] the
/// target branch, [token] a personal access token, and [configPath] /
/// [recordsDir] the in-repo paths for the shared config and recordings.
/// Default shared repository every client points at out of the box.
const String defaultSyncRepository = 'Zsdhak1/custom-client-sync';

/// Default target branch of [defaultSyncRepository].
const String defaultSyncBranch = 'main';

/// Default GitHub personal access token placeholder.
///
/// SECURITY: Never embed a real PAT in source code or committed binaries.
/// GitHub Push Protection blocks pushes containing secrets. Users must enter
/// their own PAT in Settings → Remote Sync before uploading recordings.
const String defaultSyncToken = '';

class RemoteSyncConfig {
  /// Creates a [RemoteSyncConfig].
  const RemoteSyncConfig({
    this.repository = defaultSyncRepository,
    this.branch = defaultSyncBranch,
    this.token = defaultSyncToken,
    this.configPath = 'record_config.json',
    this.recordsDir = 'records',
    this.localRecordsDir = '',
  });

  /// `owner/repo` slug of the remote repository.
  final String repository;

  /// Target branch.
  final String branch;

  /// Access token (kept out of logs; never echo its value).
  final String token;

  /// In-repo path of the shared record configuration JSON.
  final String configPath;

  /// In-repo directory holding uploaded match recordings.
  final String recordsDir;

  /// Local directory downloads are written into (typically the export dir).
  ///
  /// Not persisted to the remote config; populated at runtime from the local
  /// export directory setting.
  final String localRecordsDir;

  /// Whether a remote target exists to read from (public pulls need no token).
  bool get canPull => repository.isNotEmpty;

  /// Whether pushes/uploads are possible (writes require a token).
  bool get canPush => repository.isNotEmpty && token.isNotEmpty;

  /// Whether this config is fully populated (repository + token).
  ///
  /// Retained for callers/UI that gate write actions; equivalent to [canPush].
  bool get isConfigured => canPush;

  /// Creates a copy with selected fields replaced.
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

  /// Restores from JSON (token is intentionally NOT persisted here; store it
  /// separately in secure storage when the GitHub impl lands).
  factory RemoteSyncConfig.fromJson(Map<String, dynamic> json) {
    return RemoteSyncConfig(
      repository: json['repository'] as String? ?? defaultSyncRepository,
      branch: json['branch'] as String? ?? defaultSyncBranch,
      token: json['token'] as String? ?? defaultSyncToken,
      configPath: json['config_path'] as String? ?? 'record_config.json',
      recordsDir: json['records_dir'] as String? ?? 'records',
    );
  }

  /// Serializes to JSON (excludes [token] by design).
  Map<String, dynamic> toJson() => {
        'repository': repository,
        'branch': branch,
        'config_path': configPath,
        'records_dir': recordsDir,
      };
}

/// A recording available on the remote, before it is downloaded.
class RemoteRecordRef {
  /// Creates a [RemoteRecordRef].
  const RemoteRecordRef({
    required this.fileName,
    required this.remotePath,
    this.sizeBytes = 0,
  });

  /// Base file name.
  final String fileName;

  /// In-repo path used to fetch the file.
  final String remotePath;

  /// File size in bytes if known.
  final int sizeBytes;
}

/// Result of a sync operation, carrying a success flag and a message.
class SyncResult {
  /// Creates a [SyncResult].
  const SyncResult({required this.ok, this.message = ''});

  /// Whether the operation succeeded.
  final bool ok;

  /// Human-readable detail (shown to the user; never contains the token).
  final String message;

  /// A successful result with optional [message].
  static SyncResult success([String message = '']) =>
      SyncResult(ok: true, message: message);

  /// A failed result with [message].
  static SyncResult failure(String message) =>
      SyncResult(ok: false, message: message);
}

/// Contract for pulling the shared record config and exchanging recordings
/// with a remote store. Implementations must never throw; return a failed
/// [SyncResult] / null instead so the UI can degrade gracefully.
abstract class RemoteSyncService {
  /// Pulls the shared record config JSON. Returns the raw decoded map, or null
  /// if unavailable. Callers pass it to `RecordConfig.fromJson`.
  Future<Map<String, dynamic>?> pullRecordConfig();

  /// Pushes the local record config JSON to the remote shared location.
  Future<SyncResult> pushRecordConfig(Map<String, dynamic> config);

  /// Lists recordings available on the remote.
  Future<List<RemoteRecordRef>> listRemoteRecords();

  /// Downloads [ref] into the local export directory; returns its local path,
  /// or null on failure.
  Future<String?> downloadRecord(RemoteRecordRef ref);

  /// Uploads a local [record] to the remote records directory.
  Future<SyncResult> uploadRecord(MatchRecord record);
}

/// Local no-op implementation used until the GitHub backend is built.
///
/// Every method degrades gracefully: pulls return null/empty, pushes report a
/// "not configured" failure. Wiring callers to this today means the GitHub
/// implementation can replace it with zero changes at call sites.
class NoopRemoteSyncService implements RemoteSyncService {
  /// Creates a [NoopRemoteSyncService].
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
