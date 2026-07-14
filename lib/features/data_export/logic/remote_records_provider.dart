/// 用于浏览和下载远程比赛记录的 Riverpod Provider。
///
/// 列出共享 GitHub 仓库中保存的记录，并允许用户把选中记录下载到本地导出目录。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/remote_sync_service.dart';
import '../../settings/logic/github_sync_provider.dart';

/// 远程记录列表视图的状态。
class RemoteRecordsState {
  /// 创建 [RemoteRecordsState]。
  const RemoteRecordsState({
    this.records = const [],
    this.isLoading = false,
    this.error = '',
  });

  /// 远程端可用的记录。
  final List<RemoteRecordRef> records;

  /// 是否正在刷新或下载。
  final bool isLoading;

  /// 面向用户的错误消息；为空表示没有错误。
  final String error;

  /// 返回替换指定字段后的副本。
  RemoteRecordsState copyWith({
    List<RemoteRecordRef>? records,
    bool? isLoading,
    String? error,
  }) {
    return RemoteRecordsState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 拉取和下载远程比赛记录的通知器。
class RemoteRecordsNotifier extends StateNotifier<RemoteRecordsState> {
  /// 创建 [RemoteRecordsNotifier]。
  RemoteRecordsNotifier({required this.remote})
      : super(const RemoteRecordsState());

  /// 用于列出和下载记录的远程同步服务。
  final RemoteSyncService remote;

  /// 刷新远程记录列表。
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: '');
    try {
      final records = await remote.listRemoteRecords();
      records.sort((a, b) => a.fileName.compareTo(b.fileName));
      state = RemoteRecordsState(records: records);
    } on Exception catch (e) {
      state = RemoteRecordsState(error: '拉取失败: $e');
    }
  }

  /// 将 [ref] 下载到已配置的本地导出目录。
///
  /// 成功时返回本地路径，失败时返回 null。
  Future<String?> download(RemoteRecordRef ref) async {
    state = state.copyWith(isLoading: true, error: '');
    try {
      final path = await remote.downloadRecord(ref);
      if (path != null) {
        state = state.copyWith(isLoading: false);
        return path;
      }
      state = state.copyWith(
        isLoading: false,
        error: '下载 ${ref.fileName} 失败',
      );
      return null;
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: '下载失败: $e');
      return null;
    }
  }
}

/// 提供远程记录列表状态和下载操作。
final remoteRecordsProvider =
    StateNotifierProvider<RemoteRecordsNotifier, RemoteRecordsState>(
  (ref) => RemoteRecordsNotifier(
    remote: ref.watch(gitHubBackedSyncServiceProvider),
  ),
);
