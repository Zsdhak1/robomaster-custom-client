import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:media_kit/media_kit.dart';

import 'core/state/session_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/update/presentation/update_checker_listener.dart';
import 'features/connection/domain/robot_identity.dart';
import 'features/connection/presentation/connection_screen.dart';
import 'features/data_export/logic/auto_export_provider.dart';
import 'features/settings/logic/github_sync_provider.dart';
import 'features/settings/logic/record_config_provider.dart';
import 'features/settings/logic/settings_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Configure fvp (libmdk) for low-latency raw HEVC over the loopback bridge.
  // Mirrors the reference ffmpeg flags: force the hevc demuxer, disable
  // buffering, and keep the decode pipeline shallow. Wrapped defensively
  // because the exact option keys vary across fvp versions.
  try {
    fvp.registerWith(options: {
      'global': {
        'avformat.fflags': '+nobuffer',
        'avformat.fpsprobesize': '0',
        'avformat.analyzeduration': '100000',
        'avformat.probesize': '500000',
      },
      'player': {
        'avformat.format': 'hevc',
        'avformat.framerate': '60',
      },
      'lowLatency': 1,
    });
  } on Object catch (_) {
    // Fall back to default registration if option schema differs.
    fvp.registerWith();
  }
  runApp(
    ProviderScope(
      overrides: [
        // Route the record-config notifier's remote sync through the
        // GitHub-backed service resolved from the user's sync configuration.
        remoteSyncServiceProvider.overrideWith(
          (ref) => ref.watch(gitHubBackedSyncServiceProvider),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

/// Root application widget.
///
/// Watches the selected robot id so the whole app (login, dashboard and any
/// subsequent page) adopts the team color of the chosen side. MaterialApp
/// animates the transition between red and blue themes automatically.
class MainApp extends ConsumerWidget {
  /// Creates the [MainApp].
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedRobotIdProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Activate background auto-export on settlement.
    ref.watch(autoExportProvider);

    final accent = teamAccentColor(selectedId);
    return UpdateCheckerListener(
      child: MaterialApp(
        title: 'WOD Client',
        theme: buildTeamTheme(accent),
        darkTheme: buildTeamThemeDark(accent),
        themeMode: themeMode,
        home: const UpdateCheckerHost(
          child: ConnectionScreen(),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
