/// Riverpod provider for browsing and downloading remote match recordings.
///
/// Lists recordings stored in the shared GitHub repository and lets the user
/// download selected ones into the local export directory.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/remote_sync_service.dart';
import '../../settings/logic/github_sync_provider.dart';

/// State of the remote recordings list view.
class RemoteRecordsState {
  /// Creates a [RemoteRecordsState].
  const RemoteRecordsState({
    this.records = const [],
    this.isLoading = false,
    this.error = '',
  });

  /// Recordings available on the remote.
  final List<RemoteRecordRef> records;

  /// Whether a refresh/download is in progress.
  final bool isLoading;

  /// Human-readable error message, empty when none.
  final String error;

  /// Returns a copy with selected fields replaced.
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

/// Notifier that fetches and downloads remote match recordings.
class RemoteRecordsNotifier extends StateNotifier<RemoteRecordsState> {
  /// Creates a [RemoteRecordsNotifier].
  RemoteRecordsNotifier({required this.remote})
      : super(const RemoteRecordsState());

  /// The remote sync service used to list and download recordings.
  final RemoteSyncService remote;

  /// Refreshes the remote recording list.
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

  /// Downloads [ref] into the configured local export directory.
  ///
  /// Returns the local path on success, null on failure.
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

/// Provides the remote recordings list and download actions.
final remoteRecordsProvider =
    StateNotifierProvider<RemoteRecordsNotifier, RemoteRecordsState>(
  (ref) => RemoteRecordsNotifier(
    remote: ref.watch(gitHubBackedSyncServiceProvider),
  ),
);
