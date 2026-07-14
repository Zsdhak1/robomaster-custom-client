import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:fvp/mdk.dart' as mdk;
import 'package:media_kit/media_kit.dart';

import 'core/constants/app_strings.dart';
import 'core/responsive/desktop_design_canvas.dart';
import 'core/state/session_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/update/presentation/update_checker_listener.dart';
import 'core/window/desktop_window_frame.dart';
import 'features/connection/domain/robot_identity.dart';
import 'features/connection/presentation/connection_screen.dart';
import 'features/data_export/logic/auto_export_provider.dart';
import 'features/settings/logic/github_sync_provider.dart';
import 'features/settings/logic/record_config_provider.dart';
import 'features/settings/logic/settings_providers.dart';

/// Flutter 应用入口。
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // 将 mdk/libmpv 内部日志（解码器、解复用器、reader）输出到控制台，
  // 便于调试时定位自定义 H.264 链路的解码失败。
  if (kDebugMode) {
    mdk.setLogHandler((level, msg) {
      debugPrint('[mdk:$level] ${msg.trimRight()}');
    });
  }
  // 为 fvp（libmdk）配置低延迟原始 HEVC 回环桥接。
  // 参数与参考 ffmpeg 命令对齐：强制 hevc 解复用器、禁用缓冲，
  // 并让解码流水线保持较浅。不同 fvp 版本的选项键可能不同，因此这里做防御式兜底。
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
    // 如果选项结构与当前 fvp 版本不匹配，则退回默认注册流程。
    fvp.registerWith();
  }
  runApp(
    ProviderScope(
      overrides: [
        // 将记录配置通知器的远程同步路由到 GitHub 后端服务，
        // 服务参数来自用户保存的同步配置。
        remoteSyncServiceProvider.overrideWith(
          (ref) => ref.watch(gitHubBackedSyncServiceProvider),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

/// 根应用组件。
///
/// 监听当前选中的机器人 ID，使登录页、仪表盘和后续页面都使用对应阵营的主题色。
/// [MaterialApp] 会自动处理红蓝主题之间的过渡动画。
class MainApp extends ConsumerWidget {
  /// 创建 [MainApp]。
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedRobotIdProvider);
    final themeMode = ref.watch(themeModeProvider);

    // 激活结算阶段触发的后台自动导出。
    ref.watch(autoExportProvider);

    final accent = teamAccentColor(selectedId);
    return UpdateCheckerListener(
      child: MaterialApp(
        title: appName,
        theme: buildTeamTheme(accent),
        darkTheme: buildTeamThemeDark(accent),
        themeMode: themeMode,
        home: const UpdateCheckerHost(
          child: ConnectionScreen(),
        ),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => DesktopDesignCanvas(
          child: DesktopWindowFrame(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
