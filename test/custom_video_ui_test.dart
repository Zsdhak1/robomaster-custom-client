/// 自定义图传 UI 层的组件和单元测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_providers.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/custom_video_screen.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/widgets/crosshair_painter.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/widgets/custom_video_debug_panel.dart';

/// 调试面板可渲染的未运行状态统计快照。
CustomVideoStats _stoppedStats() => const CustomVideoStats(
      running: false,
      chunksReceived: 0,
      bytesReceived: 0,
      gateOpen: false,
      framesForwarded: 0,
      bytesForwarded: 0,
      decoderClients: 0,
      streamUrl: null,
      tsWrap: false,
      gateBufferBytes: 0,
      pendingFrames: 0,
      millisSinceLastChunk: null,
    );

/// 携带吞吐量的运行中统计快照，用于覆盖每个调试行。
CustomVideoStats _runningStats() => const CustomVideoStats(
      running: true,
      chunksReceived: 500,
      bytesReceived: 75000,
      gateOpen: true,
      framesForwarded: 120,
      bytesForwarded: 60000,
      decoderClients: 1,
      streamUrl: 'tcp://127.0.0.1:54321',
      tsWrap: true,
      gateBufferBytes: 0,
      pendingFrames: 0,
      millisSinceLastChunk: 20,
    ).withRates(
      chunksPerSec: 50,
      bytesInPerSec: 7500,
      framesPerSec: 30,
      bytesOutPerSec: 6000,
    );


void main() {
  group('CrosshairPainter', () {
    test('default constructor uses null aimCenter and line width 1', () {
      const painter = CrosshairPainter();
      expect(painter.aimCenter, isNull);
      expect(painter.lineWidth, 1);
    });

    test('shouldRepaint returns true when parameters change', () {
      const a = CrosshairPainter();
      const b = CrosshairPainter(aimCenter: Offset(50, 50));
      expect(b.shouldRepaint(a), isTrue);

      const c = CrosshairPainter(aimCenter: Offset(100, 200));
      expect(c.shouldRepaint(a), isTrue);

      const d = CrosshairPainter(lineWidth: 2);
      expect(d.shouldRepaint(a), isTrue);
    });

    test('shouldRepaint returns false for identical parameters', () {
      const a = CrosshairPainter(aimCenter: Offset(120, 80), lineWidth: 2);
      const b = CrosshairPainter(aimCenter: Offset(120, 80), lineWidth: 2);
      expect(b.shouldRepaint(a), isFalse);
    });

    test('shouldRepaint returns true when aimCenter changes from null', () {
      const a = CrosshairPainter();
      const b = CrosshairPainter(aimCenter: Offset(200, 150));
      expect(b.shouldRepaint(a), isTrue);
    });

    testWidgets('crosshair paints without error in a widget', (tester) async {
      const painter = CrosshairPainter();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: Size(200, 200),
              painter: painter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('CustomVideoScreen', () {
    testWidgets('renders app bar and custom video panel', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // 用有限流覆盖周期性统计流，避免组件测试泄漏永不结束的周期定时器。
            customVideoStatsProvider.overrideWith(
              (ref) => const Stream<CustomVideoStats>.empty(),
            ),
          ],
          child: const MaterialApp(
            home: CustomVideoScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('自定义图传 · 0x0310'), findsOneWidget);
      expect(find.byType(CustomVideoScreen), findsOneWidget);
    });
  });

  group('CustomVideoDebugContent', () {
    testWidgets('renders pipeline sections even when not running',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customVideoStatsProvider.overrideWith(
              (ref) => Stream<CustomVideoStats>.value(_stoppedStats()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CustomVideoDebugContent()),
            ),
          ),
        ),
      );
      await tester.pump();

      // 可嵌入内容始终渲染各区段；运行中和 idle 的门控现在位于共享 VideoSidePanel 封装中。
      expect(find.text('流水线状态'), findsOneWidget);
      expect(find.text('MQTT 接收 (CustomByteBlock)'), findsOneWidget);
    });

    testWidgets('renders all diagnostic sections when running', (tester) async {
      // 使用较高视口，确保懒加载 ListView 构建每个区段；
      // 解码器日志在默认测试高度下位于首屏下方。
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customVideoStatsProvider.overrideWith(
              (ref) => Stream<CustomVideoStats>.value(_runningStats()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CustomVideoDebugContent()),
            ),
          ),
        ),
      );
      await tester.pump();

      // 每个流水线阶段的区段头部都应存在。
      expect(find.text('流水线状态'), findsOneWidget);
      expect(find.text('MQTT 接收 (CustomByteBlock)'), findsOneWidget);
      expect(find.text('TCP 桥转发'), findsOneWidget);
      expect(find.textContaining('解码器'), findsWidgets);
      expect(find.text('解码器日志'), findsOneWidget);

      // 吞吐量和桥接值应可见。
      expect(find.text('tcp://127.0.0.1:54321'), findsOneWidget);
      expect(find.text('MPEG-TS'), findsOneWidget);
    });
  });
}
