/// Unit tests for GitHub remote-sync configuration and graceful degradation.
///
/// Network paths are not exercised here (no live HTTP); these tests pin the
/// config semantics and the no-credential degradation that keep the UI safe.
/// The default config points at the shared team repository and ships an
/// embedded default token, so cases that must avoid touching the network use
/// an explicit empty `repository` or an explicit empty `token`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/sync/github_sync_service.dart';
import 'package:robomaster_custom_client_1/core/sync/remote_sync_service.dart';

void main() {
  _defaultConfigTests();
  _tokenBehaviorTests();
  _repositoryBehaviorTests();
  _serializationTests();
  _degradationTests();
}

void _defaultConfigTests() {
  group('RemoteSyncConfig defaults', () {
    test('defaults to the shared team repository on main', () {
      const config = RemoteSyncConfig();
      expect(config.repository, defaultSyncRepository);
      expect(config.repository, 'Zsdhak1/custom-client-sync');
      expect(config.branch, 'main');
    });

    test('default config can pull but requires user PAT for push', () {
      const config = RemoteSyncConfig();
      expect(config.canPull, isTrue);
      expect(config.canPush, isFalse);
      expect(config.isConfigured, isFalse);
    });
  });
}

void _tokenBehaviorTests() {
  group('RemoteSyncConfig token behavior', () {
    test('explicit empty token disables push', () {
      const config = RemoteSyncConfig();
      expect(config.canPull, isTrue);
      expect(config.canPush, isFalse);
      expect(config.isConfigured, isFalse);
    });

    test('canPush and isConfigured require a token', () {
      const withToken = RemoteSyncConfig(token: 'x');
      expect(withToken.canPush, isTrue);
      expect(withToken.isConfigured, isTrue);
    });
  });
}

void _repositoryBehaviorTests() {
  group('RemoteSyncConfig repository behavior', () {
    test('an empty repository cannot pull', () {
      const blank = RemoteSyncConfig(repository: '');
      expect(blank.canPull, isFalse);
      expect(blank.canPush, isFalse);
    });
  });
}

void _serializationTests() {
  group('RemoteSyncConfig copyWith', () {
    test('preserves and overrides fields including localRecordsDir', () {
      const base = RemoteSyncConfig(repository: 'a/b', branch: 'dev');
      final next = base.copyWith(token: 't', localRecordsDir: '/tmp/out');
      expect(next.repository, 'a/b');
      expect(next.branch, 'dev');
      expect(next.token, 't');
      expect(next.localRecordsDir, '/tmp/out');
    });
  });

  group('RemoteSyncConfig serialization', () {
    test('toJson excludes the token by design', () {
      const config = RemoteSyncConfig(repository: 'a/b', token: 'secret');
      final json = config.toJson();
      expect(json.containsKey('token'), isFalse);
      expect(json['repository'], 'a/b');
    });

    test('fromJson round-trips non-secret fields', () {
      const config = RemoteSyncConfig(
        repository: 'team/repo',
        branch: 'release',
        configPath: 'cfg.json',
        recordsDir: 'rec',
      );
      final restored = RemoteSyncConfig.fromJson(config.toJson());
      expect(restored.repository, 'team/repo');
      expect(restored.branch, 'release');
      expect(restored.configPath, 'cfg.json');
      expect(restored.recordsDir, 'rec');
      expect(restored.token, defaultSyncToken);
    });

    test('fromJson falls back to defaults when absent', () {
      final restored = RemoteSyncConfig.fromJson(const {});
      expect(restored.repository, defaultSyncRepository);
      expect(restored.branch, defaultSyncBranch);
    });
  });
}

void _degradationTests() {
  group('GitHubSyncService degradation (no network)', () {
    final offline = GitHubSyncService(
      config: const RemoteSyncConfig(repository: ''),
    );

    test('pullRecordConfig returns null without a repository', () async {
      expect(await offline.pullRecordConfig(), isNull);
    });

    test('listRemoteRecords returns empty without a repository', () async {
      expect(await offline.listRemoteRecords(), isEmpty);
    });

    test('pushRecordConfig fails with an explicit empty token', () async {
      final service = GitHubSyncService(config: const RemoteSyncConfig());
      final result = await service.pushRecordConfig({'a': 1});
      expect(result.ok, isFalse);
      expect(result.message, isNotEmpty);
      expect(result.message.toLowerCase().contains('bearer'), isFalse);
    });
  });
}
