import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:robomaster_custom_client_1/core/update/domain/github_release.dart';
import 'package:robomaster_custom_client_1/core/update/logic/update_providers.dart';
import 'package:robomaster_custom_client_1/features/settings/presentation/about_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'WOD Client',
      packageName: 'com.example.robomaster_custom_client_1',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('AboutScreen renders header and repo card', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('关于'), findsOneWidget);
    expect(find.text('WOD Client'), findsOneWidget);
    expect(find.textContaining('版本'), findsOneWidget);
    expect(find.text('开源仓库'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
  });

  testWidgets('AboutScreen shows update available card', (tester) async {
    final release = GitHubRelease(
      tagName: 'v9.9.9',
      name: 'Future release',
      body: 'Big update',
      publishedAt: DateTime(2026, 6, 13),
      assets: const [],
      htmlUrl: 'https://example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateCheckResultProvider.overrideWith(
            (ref) async => UpdateCheckResult(
              hasUpdate: true,
              release: release,
              currentVersion: '0.1.0+1',
              latestVersion: '9.9.9',
            ),
          ),
        ],
        child: const MaterialApp(
          home: AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 9.9.9'), findsOneWidget);
    expect(find.text('查看新版本'), findsOneWidget);
  });
}
